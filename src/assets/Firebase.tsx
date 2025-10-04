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
  apiKey: "AIzaSyBe-8zPGr7PxjEUHiCBeGleMOoBrCT16iY",
  authDomain: "billkmotolinkltd.firebaseapp.com",
  databaseURL: "https://billkmotolinkltd-default-rtdb.firebaseio.com",
  projectId: "billkmotolinkltd",
  storageBucket: "billkmotolinkltd.firebasestorage.app",
  messagingSenderId: "930252947055",
  appId: "1:930252947055:web:4515f4fc59b6ff67b6179a",
  measurementId: "G-MW79LLNQS5"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
export const db = getFirestore(app);
export const auth = getAuth(app);
export default app;