importScripts("https://www.gstatic.com/firebasejs/10.7.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.2/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyDdWXIvY8BFixMk-nNcv_sG7C2zG468O60",
    authDomain: "winniko-579d4.firebaseapp.com",
    projectId: "winniko-579d4",
    storageBucket: "winniko-579d4.firebasestorage.app",
    messagingSenderId: "688066819982",
    appId: "1:688066819982:web:0af680960426c3959396df",
    measurementId: "G-276VR4KE3Q"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);

    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
