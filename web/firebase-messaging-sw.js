importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
     apiKey: 'AIzaSyALIuZSZ7d1jDOEavcLw4fOZA-emZhjgEQ',
     appId: '1:117943834983:web:c57a404e5c54301a3c37c2',
     messagingSenderId: '117943834983',
     projectId: 'jibli-3773e',
     authDomain: 'jibli-3773e.firebaseapp.com',
     storageBucket: 'jibli-3773e.firebasestorage.app',
     measurementId: 'G-RH1JM2WGND',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});