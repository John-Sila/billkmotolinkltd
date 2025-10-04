import { useState, type FormEvent } from "react";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth, db } from "../assets/Firebase";
import { collection, query, where, getDocs } from "firebase/firestore";
import { Toaster } from 'react-hot-toast';
import toast from 'react-hot-toast';

interface LoginProps {
  onLogin: () => void;
}

export default function Login({ onLogin }: LoginProps) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = async (e: FormEvent) => {
  e.preventDefault();
  setError("");

  try {
    // 1. Check Firestore if user is active
    const usersRef = collection(db, "users");
    const q = query(usersRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    if (querySnapshot.empty) {
      setError("User not found.");
      return;
    }

    const userDoc = querySnapshot.docs[0];
    const userData = userDoc.data();

    if (!userData.isActive) {
      setError("Inactive. Please contact support.");
      return toast("This account is not active.",
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
    }

    if (userData.isDeleted) {
      setError("Account is deleted.");
      return toast("Please inform an administrator to create you an active account.",
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
    }

    if (userData.userRank && userData.userRank  !== "Rider") {
      setError("Access denied.");
      return toast("Only riders can log in for now.",
          {
            icon: '❌',
            style: {
              borderRadius: '10px',
              background: 'black',
              color: 'white',
            },
          }
        );
    }

    // 2. Proceed to sign in
    await signInWithEmailAndPassword(auth, email, password);
    onLogin(); // trigger navigation/state change

  } catch (err: any) {
    setError(err.message);
  }
};

  return (
    <div className="loginMainDiv">
      <div><Toaster/></div>
      <div className="loginForm">
        <p className="title">BILLK MOTOLINK LTD</p>
        <form className="form">
          <div className="input-group">
            <label htmlFor="email">Username</label>
            <input type="email" name="email" id="email" placeholder="" onChange={e => setEmail(e.target.value)} />
          </div>
          <div className="input-group">
            <label htmlFor="password">Password</label>
            <input type="password" name="password" id="password" placeholder="" onChange={e => setPassword(e.target.value)} />
            <div className="forgot">
              <a rel="noopener noreferrer" href="#">Forgot Password ?</a>
            </div>
          </div>
          <button className="sign" onClick={handleSubmit}>Sign in</button>
        </form>
        {error && <p style={{ color: "red", textAlign: "center" }}>{error}</p>}
      </div>
    </div>
  );
}
