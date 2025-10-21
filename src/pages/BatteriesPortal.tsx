import toast, { Toaster } from "react-hot-toast";
import AlertDialog from "../assets/Dialog";
import logo from "../assets/logo2.png";
import { useState, useEffect } from "react";
import { db } from "../assets/Firebase";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import { doc, setDoc, getDoc, updateDoc, runTransaction, Timestamp} from "firebase/firestore";
import { fetchGeneralVariables, fetchUser, type GeneralVariables, type UserData } from "../services/userService";
import PrimaryLoadingFragment from "../assets/PrimaryLoading";

export default function BatteriesPortal() {
  const [openBatteriesPortalDialog, setOpenBatteriesPortalDialog] = useState(false);
  const [batteryName, setBatteryName] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [uid, setUid] = useState<string | null>(null);
  const [user, setUser] = useState<UserData | null>(null);
  const [generalData, setGeneralData] = useState<GeneralVariables | null>(null);
  const [selectedBatteryLocation, setSelectedBatteryLocation] = useState<string>("");

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
        const userData = await fetchUser(uid);
        const generalData = await fetchGeneralVariables();
  
        setUser(userData);
        setGeneralData(generalData);
        setLoading(false);
      }
  
      loadUser();
    }, [uid]);

  const AddBattery = (e: React.FormEvent<HTMLFormElement>) => {
      e.preventDefault();
      if (!batteryName || batteryName.trim() === "") {
          return toast("Enter a valid battery name.", {
              icon: "❗",
              style: {
                  borderRadius: "10px",
                  background: "#fff",
                  color: "red",
              },
          });
      }
      if (!selectedBatteryLocation || selectedBatteryLocation.trim() === "") {
          return toast("Select an initial location for this battery.", {
              icon: "❗",
              style: {
                  borderRadius: "10px",
                  background: "#fff",
                  color: "red",
              },
          });
      }
      setOpenBatteriesPortalDialog(true);
  }
  const handleBatteriesPortalConfirm = () => {
    setOpenBatteriesPortalDialog(false);
    addBatteryToFirestore();
  }

  async function addBatteryToFirestore() {
    const generalRef = doc(db, "general", "general_variables");

    if (!batteryName?.trim()) {
      toast.error("Please enter a valid battery name.");
      return;
    }

    if (loading) return <PrimaryLoadingFragment />;
    
    return toast.promise(
      (async () => {
        await runTransaction(db, async (transaction) => {
          const snapshot = await transaction.get(generalRef);

          const currentBatteries = (snapshot.exists() && snapshot.data().batteries
            ? snapshot.data().batteries
            : {}) as Record<
            string,
            {
              batteryName?: string;
              batteryLocation?: string;
              assignedBike?: string;
              assignedRider?: string;
              offTime?: Timestamp;
            }
          >;


          // Case-insensitive duplicate check
          const duplicateExists = Object.values(currentBatteries).some((battery) => {
            const existingName = battery?.batteryName;
            return existingName && existingName.toLowerCase() === batteryName.toLowerCase();
          });

          if (duplicateExists) {
            throw new Error("duplicate");
          }

          // Compute next numeric key
          const keys = Object.keys(currentBatteries)
            .map((k) => parseInt(k, 10))
            .filter((n) => !isNaN(n));
          const nextIndex = keys.length > 0 ? Math.max(...keys) + 1 : 0;

          const newBattery = {
            batteryName: batteryName.trim().toUpperCase(),
            batteryLocation: selectedBatteryLocation || "Unknown",
            assignedBike: "None",
            assignedRider: "None",
            offTime: Timestamp.now(),
          };

          const updatedBatteries = { ...currentBatteries, [nextIndex]: newBattery };

          if (!snapshot.exists()) {
            transaction.set(generalRef, { batteries: updatedBatteries });
          } else {
            transaction.update(generalRef, { batteries: updatedBatteries });
          }
        });

        // Optional refresh function after completion
        // loadBatteries?.();
      })(),
      {
        loading: "Adding battery...",
        success: <b>Battery added successfully.</b>,
        error: (err) =>
          err.message === "duplicate"
            ? "A battery with this name already exists."
            : <b>Failed to add battery.</b>,
      }
    );
  }
  const handleBatteriesPortalClose = () => {
    setOpenBatteriesPortalDialog(false);
  }

    
  return (
    <div className="clockouts-container">
      <div><Toaster /></div>
      <form className="form_container" onSubmit={AddBattery}>
          <div className="logo_container">
          <img className="logo" src={logo} alt="logo" width={150} height={150} />
          </div>
          <div className="title_container">
          <p className="title">Assets</p>
          <span className="subtitle">Add a battery</span>
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

                  {/* battery name */}
                  <tr>
                      <td><label className="input_label" htmlFor="batteryNumber">Battery number</label></td>
                      <input
                          type="text"
                          name="batteryNumber"
                          id="batteryNumber"
                          value={batteryName || ""}
                          onChange={(e) => setBatteryName(e.target.value)}
                          title="Battery Number" />
                  </tr>

                  {/* location */}
                  <tr>
                    <td><label className="input_label" htmlFor="location">Location</label></td>
                    <td>
                      <select
                            title="Select Location"
                            className="styled-select"
                            value={selectedBatteryLocation?.toString() ?? ""}
                            onChange={(e) => setSelectedBatteryLocation(e.target.value)}
                            >
                            <option value="">Select location</option>
                            {Object.entries(generalData?.destinations ?? {})
                              .map(([key, value]) => (
                                <option key={key} value={value}>
                                  {value}
                                </option>
                              ))}

                          </select>
                    </td>
                  </tr>

                  </tbody>
              </table>

              <button title="Clock Out" type="submit" className="sign-in_btn" >
                  <span>Add Bike</span>
              </button>

          </div>

          <div className="separator">
          <hr className="line" />
          <span className="note">Asset Management</span>
          <hr className="line" />
          </div>
      </form>

      <AlertDialog
          open={openBatteriesPortalDialog}
          title="Confirm action"
          description="Are you sure you want to add this bike?"
          onConfirm={handleBatteriesPortalConfirm}
          onClose={handleBatteriesPortalClose}
          />
    </div>
  );
}
