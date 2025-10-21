import { useState, type FormEvent } from "react";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth, db } from "../assets/Firebase";
import { collection, query, where, getDocs } from "firebase/firestore";
import { Toaster } from 'react-hot-toast';
import toast from 'react-hot-toast';
import logo from "../assets/logo2.png";

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

    if (userData.userRank && userData.userRank  !== "Rider" && userData.userRank !== "Systems, IT") {
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

      <form className="form_container" onSubmit={handleSubmit}>
        <div className="logo_container">
          <img className="logo" src={logo} alt="logo" width={150} height={150} />
        </div>
        <div className="title_container">
          <p className="title">Authenticator</p>
          <span className="subtitle">Please sign in.</span>
        </div>
        <br />

        <table>
          <tbody>
            <tr>
              <td><label className="input_label" htmlFor="loginEmail">Email</label></td>
              <td>
                <input type="email"
                  className="input_field"
                    value={email}
                    onChange={(e) =>
                      setEmail(e.target.value)
                    }
                    title="Login Email" name="loginEmail" id="loginEmail" />
              </td>
            </tr>
            <tr>
              <td><label className="input_label" htmlFor="loginPassword">Password</label></td>
              <td>
                <input type="password"
                  className="input_field"
                    value={password}
                    onChange={(e) =>
                      setPassword(e.target.value)
                    }
                    title="Login Password" name="loginPassword" id="loginPassword" />
              </td>
            </tr>
          </tbody>
        </table>

        <div className="forgot">
          <a rel="noopener noreferrer" href="#">Forgot Password?</a>
        </div>
        <button className="sign-in_btn" onClick={handleSubmit}>Sign in</button>

        {error && <p style={{ color: "red", textAlign: "center" }}>{error}</p>}
        <div className="separator">
          <hr className="line" />
          <span className="note">Authenticator</span>
          <hr className="line" />
        </div>
      </form>
    </div>
  );
}
