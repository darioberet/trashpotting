// Service worker delle notifiche push sul web (Firebase Cloud Messaging).
// Deve stare nella radice del sito: Firebase lo cerca in
// /firebase-messaging-sw.js anche se l'app è servita da /app/.
// Le notifiche con titolo e testo le mostra il browser da solo; il tocco apre
// il link impostato dalla Cloud Function (webpush.fcmOptions.link).
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

// Stessi valori di DefaultFirebaseOptions.web (lib/firebase_options.dart):
// sono pubblici, la sicurezza la fanno le regole.
firebase.initializeApp({
  apiKey: 'AIzaSyBloMJQg6uTXwzmwX5OwYF_oNu9oW7vB5M',
  appId: '1:1059796102944:web:600233b1b7fe45092d3145',
  messagingSenderId: '1059796102944',
  projectId: 'trashpotting-app',
  authDomain: 'trashpotting-app.firebaseapp.com',
  storageBucket: 'trashpotting-app.firebasestorage.app',
});

firebase.messaging();
