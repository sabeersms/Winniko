const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

// KEYS
const CRIC_API_KEY = "3df386fb-a73f-44a5-a174-ed6801ad6d33";

/**
 * Scheduled Function: Runs every 2 hours to keep data fresh
 */
exports.scheduledScoreSync = functions.pubsub
  .schedule("every 2 hours")
  .onRun(async (context) => {
    console.log("⏰ STARTED: Scheduled Score Sync");
    try {
      const snapshot = await db.collection("competitions").get();
      const promises = [];
      snapshot.forEach((doc) => {
        const data = doc.data();
        const leagueId = data.leagueId;
        const sport = data.sport || "";
        if (leagueId && leagueId.length > 0) {
          promises.push(syncCompetition(doc.id, leagueId, sport));
        }
      });
      await Promise.all(promises);
      console.log("✅ FINISHED: Scheduled Score Sync");
      return null;
    } catch (error) {
      console.error("❌ ERROR in Scheduled Sync:", error);
      return null;
    }
  });

/**
 * Syncs a single competition
 */
async function syncCompetition(competitionId, leagueId, sport) {
  console.log(`Processing Competition: ${competitionId} (League: ${leagueId})`);
  try {
    const isCricket = sport.toLowerCase().includes("cricket") || leagueId.includes("cwc") || leagueId.includes("ipl");

    // 1. Get Teams for winner resolution
    const teamsSnapshot = await db.collection("competitions").doc(competitionId).collection("teams").get();
    const teamNameMap = {};
    teamsSnapshot.forEach(doc => {
      const data = doc.data();
      teamNameMap[normalize(data.name)] = doc.id;
      if (data.shortName) teamNameMap[normalize(data.shortName)] = doc.id;
    });

    // 2. Fetch remote data
    let remoteMatches = [];
    if (isCricket) {
      remoteMatches = await fetchCricApiMatches(leagueId);
    } else {
      remoteMatches = [];
    }

    if (!remoteMatches || remoteMatches.length === 0) return;

    // 3. Update Firestore
    const batch = db.batch();
    const matchesRef = db.collection("competitions").doc(competitionId).collection("matches");
    const existingSnapshot = await matchesRef.get();

    let updatedCount = 0;
    existingSnapshot.forEach((doc) => {
      const existing = doc.data();
      if (existing.actualScore?.verified === true || existing.actualScore?.manuallyScored === true) return;

      const remote = findMatch(existing, remoteMatches);
      if (remote) {
        const updates = {};
        const newStatus = normalizeStatus(remote.status);
        if (existing.status !== newStatus) updates.status = newStatus;

        if (remote.score) {
          const score = remote.score;
          const result = (remote.result || "").toLowerCase();
          let winnerId = null;

          if (isCricket) {
            // Cricket Winner Logic
            for (const [name, id] of Object.entries(teamNameMap)) {
              if (result.includes(name) && (result.includes("won") || result.includes("beat"))) {
                winnerId = id; break;
              }
            }
            if (!winnerId && newStatus === 'completed') {
              const t1r = parseInt(score.t1Runs) || 0;
              const t2r = parseInt(score.t2Runs) || 0;
              if (t1r > t2r) winnerId = existing.team1Id;
              else if (t2r > t1r) winnerId = existing.team2Id;
            }
            if (result.includes("tied")) winnerId = "tied";
            if (result.includes("no result")) winnerId = "no_result";

            // Margin
            let marginType = ""; let marginValue = "";
            if (result.includes("won by")) {
              const parts = result.split("won by");
              if (parts.length > 1) {
                const after = parts[1].trim();
                const m = after.match(/(\d+)/);
                if (m) marginValue = m[1];
                if (after.includes("run")) marginType = "runs";
                else if (after.includes("wicket")) marginType = "wickets";
              }
            }
            score.winnerId = winnerId;
            score.marginType = marginType;
            score.marginValue = marginValue;
          } else {
            // Football
            const t1 = parseInt(score.team1) || 0;
            const t2 = parseInt(score.team2) || 0;
            if (newStatus === 'completed') {
              if (t1 > t2) winnerId = existing.team1Id;
              else if (t2 > t1) winnerId = existing.team2Id;
              else winnerId = "tied";
            }
            score.winnerId = winnerId;
            if (winnerId === "tied") score.marginType = "tie";
          }
          updates.actualScore = score;
        }

        if (Object.keys(updates).length > 0) {
          batch.update(doc.ref, updates);
          updatedCount++;
        }
      }
    });

    if (updatedCount > 0) {
      await batch.commit();
      console.log(`✅ Updated ${updatedCount} matches for ${competitionId}`);
      await recalculateLeaderboard(competitionId);
    }
  } catch (e) {
    console.error(`❌ Sync error for ${competitionId}:`, e);
  }
}

/**
 * Fetch matches from CricAPI
 */
async function fetchCricApiMatches(seriesId) {
  try {
    const url = `https://api.cricapi.com/v1/currentMatches?apikey=${CRIC_API_KEY}&offset=0`;
    const resp = await axios.get(url);
    if (!resp.data || !resp.data.data) return [];
    return resp.data.data.map(m => ({
      teamInfo: m.teamInfo,
      team1: m.teamInfo?.[0]?.name || "",
      team2: m.teamInfo?.[1]?.name || "",
      status: m.matchEnded ? "Completed" : "Live",
      result: m.status || "",
      score: {
        t1Runs: parseInt(m.score?.[0]?.r) || 0,
        t2Runs: parseInt(m.score?.[1]?.r) || 0,
        t1Wickets: parseInt(m.score?.[0]?.w) || 0,
        t2Wickets: parseInt(m.score?.[1]?.w) || 0,
        t1Overs: m.score?.[0]?.o || 0,
        t2Overs: m.score?.[1]?.o || 0
      }
    }));
  } catch (e) { return []; }
}

/**
 * Main Leaderboard Recalculation logic
 */
async function recalculateLeaderboard(competitionId) {
  console.log(`🔄 RECALCULATING: ${competitionId}`);
  try {
    const compDoc = await db.collection("competitions").doc(competitionId).get();
    if (!compDoc.exists) return;
    const competition = compDoc.data();
    const sportStr = (competition.sport || "Football").toLowerCase();
    const isCricket = sportStr.includes("cricket");

    const rules = competition.rules || { correctWinner: 3, correctScore: 2 };
    const pWinner = rules.correctWinner || 3;
    const pScore = rules.correctScore || 2;

    const matchesSnapshot = await db.collection("competitions").doc(competitionId).collection("matches").get();
    const participantsSnapshot = await db.collection("competitions").doc(competitionId).collection("participants").get();
    const predictionsSnapshot = await db.collection("predictions").where("competitionId", "==", competitionId).get();

    const matchesMap = {};
    matchesSnapshot.forEach(doc => { matchesMap[doc.id] = doc.data(); });

    // 1. Initialize Stats
    const stats = {};
    participantsSnapshot.forEach(doc => {
      const d = doc.data();
      const userId = d.userId || doc.id;
      stats[userId] = {
        totalPoints: 0, perfectScores: 0, correctOutcomes: 0, totalPredictionsCount: 0,
        ref: doc.ref,
        curP: d.totalPoints || 0, curPerf: d.perfectScores || 0,
        curOut: d.correctOutcomes || 0, curTot: d.totalPredictions || 0,
        curRank: d.rank || 0
      };
    });

    // 2. Map and Count ALL predictions
    const predictionsToProcess = [];
    predictionsSnapshot.forEach(doc => {
      const d = doc.data();
      const userId = d.userId;
      if (stats[userId]) {
        stats[userId].totalPredictionsCount++;
        predictionsToProcess.push({ id: doc.id, ref: doc.ref, data: d });
      }
    });

    const predUpdates = [];

    // 3. Calculate points for each prediction
    predictionsToProcess.forEach(item => {
      const p = item.data;
      const match = matchesMap[item.data.matchId];
      if (!match || !match.actualScore) return;

      const mStatus = (match.status || "").toLowerCase();
      const isFinishedStatus = mStatus.includes("complete") || mStatus.includes("ended") || mStatus === "ft" || mStatus === "finished" || mStatus === "final";
      const isVerified = match.actualScore.verified === true || match.actualScore.manuallyScored === true;

      // Only score if finished OR verified result exists
      if (!isFinishedStatus && !isVerified) return;

      const act = match.actualScore;
      const pred = p.prediction;
      let pts = 0; let isPerf = false; let isOut = false;

      if (isCricket) {
        // Cricket
        let actWin = act.winnerId;
        const prWin = pred.winnerId;

        // Infer Winner for Cloud Function as well
        if (!actWin && act.t1Runs !== undefined) {
          const t1 = parseInt(act.t1Runs) || 0;
          const t2 = parseInt(act.t2Runs) || 0;
          if (t1 > t2) actWin = match.team1Id;
          else if (t2 > t1) actWin = match.team2Id;
          else if (t1 === t2 && t1 !== 0) actWin = "tied";
        }

        if (actWin && actWin === prWin) { pts = pWinner; isOut = true; }

        let actMT = (act.marginType || "").toLowerCase();
        const actMV = (act.marginValue || "").toString();
        const pR = (pred.runs || "").toString();
        const pW = (pred.wickets || "").toString();

        // Infer Margin Type for Cloud Function
        if (!actMT && actMV && act.battingFirstId) {
          actMT = (act.battingFirstId === actWin) ? "runs" : "wickets";
        }

        let mOk = false;
        if (actMT === 'runs' && pR) mOk = checkMargin(actMV, pR, 'runs');
        else if (actMT === 'wickets' && pW) mOk = checkMargin(actMV, pW, 'wickets');

        if (actWin === 'tied' && prWin === 'tied') { mOk = true; if (!isOut) { pts = pWinner; isOut = true; } }

        if (mOk && (isOut || actWin === 'tied')) {
          pts += pScore;
          if (isOut) isPerf = true;
        }
      } else {
        // Football - Robust
        const act1 = act.team1; const act2 = act.team2;
        const pr1 = pred.team1; const pr2 = pred.team2;
        const actH = parseInt(act1); const actA = parseInt(act2);
        const prH = parseInt(pr1); const prA = parseInt(pr2);

        const aTie = (act.marginType === 'tie') || (act1 !== undefined && actH === actA);
        const pTie = (pred.isTie === true) || (pr1 !== undefined && prH === prA);

        if (aTie && pTie) {
          pts = pWinner; isOut = true;
          if (act1 !== undefined && pr1 !== undefined && actH === prH && actA === prA) { pts += pScore; isPerf = true; }
        } else if (!aTie && !pTie) {
          const actW = actH > actA ? "h" : "a";
          const prW = prH > prA ? "h" : "a";
          if (actW === prW) {
            pts = pWinner; isOut = true;
            if (actH === prH && actA === prA) { pts += pScore; isPerf = true; }
          }
        }
      }

      // Add to user stats
      const uid = p.userId;
      stats[uid].totalPoints += pts;
      if (isPerf) stats[uid].perfectScores++;
      if (isOut) stats[uid].correctOutcomes++;

      // Queue prediction doc update
      predUpdates.push({ ref: item.ref, pts, isPerf, isOut });
    });

    // 4. Ranking
    const sortedIds = Object.keys(stats).sort((a, b) => stats[b].totalPoints - stats[a].totalPoints);
    for (let i = 0; i < sortedIds.length; i++) {
      const uid = sortedIds[i];
      if (i > 0 && stats[uid].totalPoints === stats[sortedIds[i - 1]].totalPoints) stats[uid].rank = stats[sortedIds[i - 1]].rank;
      else stats[uid].rank = i + 1;
    }

    // 5. Batch Update Participants
    let batch = db.batch();
    let bCount = 0;
    sortedIds.forEach(uid => {
      const s = stats[uid];
      if (s.curP !== s.totalPoints || s.curPerf !== s.perfectScores || s.curOut !== s.correctOutcomes || s.curTot !== s.totalPredictionsCount || s.curRank !== s.rank) {
        batch.update(s.ref, {
          totalPoints: s.totalPoints,
          perfectScores: s.perfectScores,
          correctOutcomes: s.correctOutcomes,
          totalPredictions: s.totalPredictionsCount,
          rank: s.rank
        });
        bCount++;
        if (bCount >= 450) { bCount = 0; batch.commit(); batch = db.batch(); }
      }
    });
    if (bCount > 0) await batch.commit();

    // 6. Batch Update Predictions
    batch = db.batch();
    bCount = 0;
    predUpdates.forEach(up => {
      batch.update(up.ref, {
        points: up.pts,
        wasPerfectScore: up.isPerf,
        wasCorrectOutcome: up.isOut,
        isScored: true
      });
      bCount++;
      if (bCount >= 450) { bCount = 0; batch.commit(); batch = db.batch(); }
    });
    if (bCount > 0) await batch.commit();

    console.log(`✅ Success: Updated ${sortedIds.length} participants and ${predUpdates.length} predictions for ${competitionId}`);
  } catch (e) { console.error("Leaderboard Error:", e); }
}

function checkMargin(act, pred, type) {
  if (type === 'wickets') return act === pred;
  const a = parseInt(act); if (isNaN(a)) return false;
  if (pred.includes('+')) return a >= parseInt(pred.replace('+', ''));
  if (pred.includes('-')) {
    const p = pred.split('-');
    return a >= parseInt(p[0]) && a <= parseInt(p[1]);
  }
  return act === pred;
}

function findMatch(loc, remL) {
  const t1 = normalize(loc.team1Name); const t2 = normalize(loc.team2Name);
  return remL.find(r => {
    const r1 = normalize(r.team1); const r2 = normalize(r.team2);
    return (r1.includes(t1) && r2.includes(t2)) || (r1.includes(t2) && r2.includes(t1));
  });
}

function normalize(s) { return (s || "").toLowerCase().replace(/[^a-z0-9]/g, ""); }
function normalizeStatus(s) {
  const l = (s || "").toLowerCase();
  if (l.includes("ended") || l.includes("finished") || l.includes("completed")) return "completed";
  if (l.includes("live") || l.includes("running") || l.includes("started")) return "live";
  return "scheduled";
}
