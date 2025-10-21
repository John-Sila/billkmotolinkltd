// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyCuuQBY-oktLkfi3q6T7RwL4q_XsBJ-K3k",
  authDomain: "billk1.firebaseapp.com",
  projectId: "billk1",
  storageBucket: "billk1.firebasestorage.app",
  messagingSenderId: "913993722547",
  appId: "1:913993722547:web:e90b28d36ee32a4be45ec6",
  measurementId: "G-M4V2210K36"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
export const db = getFirestore(app);
export const auth = getAuth(app);
export default app;