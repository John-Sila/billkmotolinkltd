import toast, { Toaster } from "react-hot-toast";
import AlertDialog from "../assets/Dialog";
import { useEffect, useState } from "react";
import logo from "../assets/logo2.png";
import { 
    getAuth,
    onAuthStateChanged,
    createUserWithEmailAndPassword, 
    signInWithEmailAndPassword, 
    signOut, 
    reauthenticateWithCredential, 
    EmailAuthProvider  } from "firebase/auth";
import { fetchUser, type UserData } from "../services/userService";
import PrimaryLoadingFragment from "../assets/PrimaryLoading";
import { auth, db } from "../assets/Firebase";
import { doc, setDoc, getDoc, updateDoc, runTransaction, Timestamp, serverTimestamp} from "firebase/firestore";
import { FirebaseError } from "firebase/app";

export default function UserManagement() {

    const [loading, setLoading] = useState(true);
    const [uid, setUid] = useState<string | null>(null);
    const [user, setUser] = useState<UserData | null>(null);
    const [currentEmail, setCurrentEmail] = useState<string | null>(null);
    const [openUserManagementDialog, setOpenUserManagementDialog] =  useState(false);
    const [fullName, setFullName] = useState<string | null>(null);
    const [newUserEmail, setNewUserEmail] = useState<string | null>(null);
    const [password, setPassword] = useState<string | null>(null);
    const [idNumber, setIdNumber] = useState<string | null>(null);
    const [phoneNumber, setPhoneNumber] = useState<string | null>(null);
    const [selectedGender, setSelectedGender] = useState<string>("");
    const [selectedRole, setSelectedRole] = useState<string>("");

    // on component load, check auth state
    useEffect(() => {
        const auth = getAuth();
        const unsubscribe = onAuthStateChanged(auth, (firebaseUser) => {
        if (firebaseUser) {
            setUid(firebaseUser.uid);
        } else {
            setUid(null);
            setLoading(false);
        }
        });
    
        return () => unsubscribe();
    }, []);
          
    // after uid, fetch data
    useEffect(() => {
        if (!uid) return;
    
        async function loadUser() {
            const userData = await fetchUser(uid || "");
        
            setUser(userData);
            setLoading(false);
            setCurrentEmail(userData?.email)
        }
    
        loadUser();
    }, [uid]);
    

    const AddUser = async(e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        if (!fullName || fullName.trim() == "" || fullName.trim().split(" ").length < 2) {
            return toast("Enter a valid name.", {
              icon: "❗",
              style: {
                  borderRadius: "10px",
                  background: "#fff",
                  color: "red",
              },
          });
        }
        if (!password || password.trim() == "" || password.length < 7) {
            return toast("Please use a stronger password.", {
              icon: "❗",
              style: {
                  borderRadius: "10px",
                  background: "#fff",
                  color: "red",
              },
          });
        }
        setOpenUserManagementDialog(true);
    };

    async function createNewUser() {
        const admin = auth.currentUser;
        if (!admin) return toast.error("No active admin session");

        // Request admin password in a modal dialog
        const adminPassword = prompt("Please re-enter your password to authorize this action:");
        if (!adminPassword) return toast.error("Authorization cancelled");

        toast.loading("Reauthenticating...");
        try {
            // Step 1: Reauthenticate admin
            const credential = EmailAuthProvider.credential(admin.email, adminPassword);
            await reauthenticateWithCredential(admin, credential);
            toast.dismiss();
            toast.success("Reauthenticated");

            // Step 2: Create new user
            toast.loading("Creating user...");
            const userCredential = await createUserWithEmailAndPassword(auth, newUserEmail, password);
            const newUser = userCredential.user;

            // Step 3: Write to Firestore
            const userDoc = doc(db, "users", newUser.uid);
            await setDoc(userDoc, {
                userName: fullName,
                email: newUserEmail,
                idNumber,
                phoneNumber,
                userRank: selectedRole,
                createdAt: serverTimestamp(),
                isVerified: false,
                isDeleted: false,
                isActive: true,
                pendingAmount: 0,
                lastClockDate: serverTimestamp(),
                currentInAppBalance: 0,
                dailyTarget: 2200,
                gender: selectedGender,
                sundayTarget: 670,
                isWorkingOnSunday: false,
                hrsPerShift: 8,
            });

            toast.dismiss();
            toast.success("User registered successfully");

            // Step 4: Restore previous admin session
            toast.loading("Restoring previous session...");
            await signOut(auth);
            await signInWithEmailAndPassword(auth, admin.email, adminPassword);
            toast.dismiss();
            toast.success("Admin session restored");

            // Step 5: Clear input fields
            setFullName(null);
            setNewUserEmail(null);
            setPassword(null);
            setIdNumber(null);
            setPhoneNumber(null);
            setSelectedGender("");
            setSelectedRole("");
        } catch (error) {
            toast.dismiss();

            if (error instanceof FirebaseError) {
                switch (error.code) {
                case "auth/email-already-in-use":
                    toast.error("This email is already registered. Try another one.");
                    break;

                case "auth/invalid-email":
                    toast.error("The provided email address is invalid.");
                    break;

                case "auth/weak-password":
                    toast.error("The password is too weak. Use at least 6 characters.");
                    break;

                case "auth/operation-not-allowed":
                    toast.error("Email/password accounts are currently disabled.");
                    break;

                case "auth/requires-recent-login":
                    toast.error("Reauthentication required. Please re-enter your credentials.");
                    break;

                case "auth/invalid-credential":
                    toast.error("Incorrect password. Could not reauthenticate.");
                    break;

                case "permission-denied":
                    toast.error("You don't have permission to perform this action.");
                    break;

                default:
                    toast.error(`Firebase error: ${error.message}`);
                    break;
                }
            } else if (error instanceof Error) {
                toast.error(`Unexpected error: ${error.message}`);
            } else {
                toast.error("An unknown error occurred.");
            }
            }

    }

    const handleUserManagementConfirm = () => {
        setOpenUserManagementDialog(false);
        createNewUser()
    }
    const handleUserManagementClose = () => {
        setOpenUserManagementDialog(false);
    }

  
    if (loading) return <PrimaryLoadingFragment />;
  
    return (
        <div className="clockouts-container">
        <div><Toaster /></div>
        <form className="form_container" onSubmit={AddUser}>
            <div className="logo_container">
            <img className="logo" src={logo} alt="logo" width={150} height={150} />
            </div>
            <div className="title_container">
            <p className="title">Users</p>
            <span className="subtitle">Add a user</span>
            </div>
            <br />

            <div>
                <table>
                    <thead>
                    <tr>
                        <th>Parameter</th>
                        <th>Value</th>
                    </tr>
                    </thead>

                    <tbody>

                    {/* user name */}
                    <tr>
                        <td><label className="input_label" htmlFor="fullName">Full Name</label></td>
                        <input
                            type="text"
                            name="fullName"
                            id="fullName"
                            value={fullName || ""}
                            onChange={(e) => setFullName(e.target.value)}
                            title="Full Name" required aria-required/>
                    </tr>
                    <tr>
                        <td><label className="input_label" htmlFor="email">Email</label></td>
                        <input
                            type="email"
                            name="email"
                            id="email"
                            value={newUserEmail || ""}
                            onChange={(e) => setNewUserEmail(e.target.value)}
                            title="Email" required aria-required/>
                    </tr>
                    <tr>
                        <td><label className="input_label" htmlFor="password">Password</label></td>
                        <input
                            type="text"
                            name="password"
                            id="password"
                            value={password || ""}
                            onChange={(e) => setPassword(e.target.value)}
                            title="Battery Number" required aria-required/>
                    </tr>
                    
                    <tr>
                        <td><label className="input_label" htmlFor="idNumber">ID Number</label></td>
                        <input
                            type="number"
                            name="idNumber"
                            id="idNumber"
                            onWheel={e => e.currentTarget.blur()}
                            value={idNumber || ""}
                            onChange={(e) => setIdNumber(e.target.value)}
                            title="ID Number" required aria-required/>
                    </tr>

                    <tr>
                        <td><label className="input_label" htmlFor="phoneNumber">Phone Number</label></td>
                        <input
                            type="number"
                            name="phoneNumber"
                            onWheel={e => e.currentTarget.blur()}
                            id="phoneNumber"
                            value={phoneNumber || ""}
                            onChange={(e) => setPhoneNumber(e.target.value)}
                            title="Phone Number" required aria-required/>
                    </tr>


                    {/* gender */}
                    <tr>
                        <td><label className="input_label" htmlFor="gender">Gender</label></td>
                        <td>
                        <select
                                title="Select Gender"
                                name="gender"
                                id="gender"
                                className="styled-select"
                                value={selectedGender?.toString() ?? ""}
                                onChange={(e) => setSelectedGender(e.target.value)}
                                required aria-required
                                >
                                <option value="">Select gender</option>
                                <option value="Male">Male</option>
                                <option value="Female">Female</option>
                            </select>
                        </td>
                    </tr>

                    {/* role */}
                    <tr>
                        <td><label className="input_label" htmlFor="role">Role</label></td>
                        <td>
                            <select
                                title="Select Role"
                                name="role"
                                id="role"
                                className="styled-select"
                                value={selectedRole?.toString() ?? ""}
                                onChange={(e) => setSelectedRole(e.target.value)}
                                required aria-required
                                >
                                <option value="">Select role</option>
                                <option value="Rider">Rider</option>
                                <option value="Admin">Administrator</option>
                                <option value="HR">Human Resource</option>
                            </select>
                        </td>
                    </tr>

                    </tbody>
                </table>

                <button title="Add User" type="submit" className="sign-in_btn" >
                    <span>Add User</span>
                </button>

            </div>

            <div className="separator">
            <hr className="line" />
            <span className="note">Personnel</span>
            <hr className="line" />
            </div>
        </form>

        <AlertDialog
            open={openUserManagementDialog}
            title="Confirm action"
            description="Are you sure you want to add this bike?"
            onConfirm={handleUserManagementConfirm}
            onClose={handleUserManagementClose}
            />
        </div>
    );
}
