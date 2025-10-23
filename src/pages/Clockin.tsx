/* eslint-disable @typescript-eslint/no-explicit-any */
import { useEffect, useState } from "react";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import { fetchGeneralVariables, fetchUser, type GeneralVariables, type UserData } from "../services/userService";
import PrimaryLoadingFragment from "../assets/PrimaryLoading";
import NoUserFound from "../assets/NoUserFound";
import CompanyPaused from '../assets/CompanyState';
import logo from "../assets/logo2.png";
import { Toaster } from "react-hot-toast";
import toast from 'react-hot-toast';
import { doc, getDoc, updateDoc, serverTimestamp } from "firebase/firestore";
import AlertDialog from "../assets/Dialog";
import { auth, db } from "../assets/Firebase";

export default function Clockin() {
  const [user, setUser] = useState<UserData | null>(null);
  const [generalData, setGeneralData] = useState<GeneralVariables | null>(null);
  const [loading, setLoading] = useState(true);
  const [mileage, setMileage] = useState<string>("");
  const [uid, setUid] = useState<string | null>(null);
  const [selectedBike, setSelectedBike] = useState<string | null>(null);
  const [selectedSwapLocation, setSelectedSwapLocation] = useState<string | null>(null);
  const [selectedDropLocation, setSelectedDropLocation] = useState<string | null>(null);
  const [selectedBatteries, setSelectedBatteries] = useState<string[]>([]);
  const [selectedLoadBatteries, setSelectedLoadBatteries] = useState<string[]>([]);
  const [selectedDropBatteries, setSelectedDropBatteries] = useState<string[]>([]);
  const [swapBatteriesOff, setSwapBatteriesOff] = useState<string[]>([]);
  const [swapBatteriesOn, setSwapBatteriesOn] = useState<string[]>([]);
  const [ourBatteriesCount, setOurBatteriesCount] = useState<null | number>(null);
  const [freeBatteriesCount, setFreeBatteriesCount] = useState<number>(0);
  const [freeBikesCount, setFreeBikesCount] = useState<number>(0);
  const [openClockInDialog, setOpenClockInDialog] = useState(false);
  const [openSwapDialog, setOpenSwapDialog] = useState(false);
  const [openLoadDialog, setOpenLoadDialog] = useState(false);
  const [openDropDialog, setOpenDropDialog] = useState(false);

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
        const generalData = await fetchGeneralVariables();

        setUser(userData);
        setGeneralData(generalData);
        setLoading(false);

        const userName = userData?.userName; // grab from user doc
        const batteries = generalData?.batteries || {};

        const batteriesAssignedToMe = Object.values(batteries).filter(
          (battery: any) => battery.assignedRider === userName
        ).length;
        const freeBatteries = Object.values(batteries).filter(
          (battery: any) => battery.assignedRider === "None"
        ).length;

        const unassignedBikes = Object.entries(generalData?.bikes ?? {}).filter(
          ([, bike]) => bike.isAssigned === false
        ).length;

        setOurBatteriesCount(batteriesAssignedToMe);
        setFreeBatteriesCount(freeBatteries)
        setFreeBikesCount(unassignedBikes)
      }

      loadUser();
    }, [uid]);

    if (loading) return <PrimaryLoadingFragment />;

    if (!user) {
        toast("We couldn't find your account.",
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
      return <NoUserFound />;
    }

    if (generalData?.companyState == "Paused") {
      toast("Fatal crash. Operation was auto-cancelled.",
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
      return <CompanyPaused />;
    }

    const ClockIn = async (e: React.FormEvent) => {
      e.preventDefault();

      // no bike selected
      if (selectedBike === "" || selectedBike === null) {
        return toast("Select a bike.",
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

      // no batteries selected
      if (selectedBatteries.length == 0) {
        return toast("Select at least one battery.",
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

      // all rentals
      if (selectedBatteries.length > 0 && selectedBatteries.every((b) => b.toUpperCase().includes("RENT"))) {
        return toast("You cannot clock in with only rentals.", {
          icon: "❗",
          style: {
            borderRadius: "10px",
            background: "#fff",
            color: "red",
          },
        });
      }


      // mileage lacking
      if (mileage === "" || isNaN(Number(mileage)) || Number(mileage) < 0) {
        return toast("Mileage is invalid.", {
          icon: "❗",
          style: {
            borderRadius: "10px",
            background: "#fff",
            color: "red",
          },
        });
      }

      // we are good
      setOpenClockInDialog(true);
    }

    const handleClockInConfirm = async () => {
      setOpenClockInDialog(false);

      try {
        await toast.promise(
          (async () => {
            // 1. Get current user
            const uid = auth.currentUser?.uid;
            if (!uid) throw new Error("User not authenticated");

            // 2. Fetch userName
            const userDocRef = doc(db, "users", uid);
            const userDoc = await getDoc(userDocRef);
            const userName = userDoc.get("userName");
            if (!userName) throw new Error("User name not found");

            // 3. Reference to batteries map
            const batteriesDocRef = doc(db, "general", "general_variables");
            const batteriesDocSnap = await getDoc(batteriesDocRef);

            if (!batteriesDocSnap.exists()) {
              throw new Error("Batteries document not found");
            }

            const batteriesData = batteriesDocSnap.get("batteries") || {};
            // 4. Update each selected battery
            const updates: Record<string, any> = {};
            Object.entries(batteriesData).forEach(([key, value]: [string, any]) => {
              if (selectedBatteries.includes(value.batteryName)) {
                console.log("Updating battery:", value.batteryName, "at key:", key);

                updates[`batteries.${key}.assignedBike`] = selectedBike;
                updates[`batteries.${key}.assignedRider`] = userName;
                updates[`batteries.${key}.batteryLocation`] = "In Motion";
                updates[`batteries.${key}.offTime`] = serverTimestamp();
              }
            });

            if (Object.keys(updates).length === 0) {
              throw new Error("No matching batteries to update");
            }

            await updateDoc(batteriesDocRef, updates);

            // 5. Update user flag
            await updateDoc(userDocRef, {
              isClockedIn: true,
              currentBike: selectedBike,
              clockinMileage: Number(mileage),
              clockinTime: serverTimestamp(),
            });

             // 7. Update selected bike
            const generalRef = doc(db, "general", "general_variables");
            const generalSnap = await getDoc(generalRef);
            const bikesData = generalSnap.get("bikes") || {};
            if (selectedBike) {
              if (bikesData[selectedBike]) {
                const bikeUpdates: Record<string, any> = {};
                bikeUpdates[`bikes.${selectedBike}.assignedRider`] = userName;
                bikeUpdates[`bikes.${selectedBike}.isAssigned`] = true;
                await updateDoc(generalRef, bikeUpdates);
              } else {
                console.warn("Selected bike was not found in bikes map:", selectedBike);
              }
            }

            // 6. Reset mileage
            setMileage("");
          })(),
          {
            loading: "Clocking in...",
            success: <b>You are good to go.</b>,
            error: <b>Could not clock in.</b>,
          }
        );
      } catch (err) {
        console.error("Error clocking in:", err);
        return toast((err as Error).message, {
          icon: "❗",
          style: {
            borderRadius: "10px",
            background: "#fff",
            color: "red",
          },
        });
      } finally {
          location.reload();
      }
    };

    const handleClockInClose = () => {
      setOpenClockInDialog(false);
    };

    const DropBattery = async (e: React.FormEvent) => {
      e.preventDefault();
      if (selectedDropBatteries.length == 0) {
        return toast("Select at least one battery to offload.",
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
      if (selectedDropLocation === "" || selectedDropLocation === null) {
        return toast("Select your offload location.",
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
      setOpenDropDialog(true);
    }
    const handleDropConfirm = async () => {
      setOpenDropDialog(false);

      try {
        await toast.promise(
          (async () => {
            // 1) Read general document
            const generalRef = doc(db, "general", "general_variables");
            const generalSnap = await getDoc(generalRef);
            if (!generalSnap.exists()) throw new Error("general_variables not found");

            const batteriesData: Record<string, any> = generalSnap.get("batteries") || {};

            // 2) Build a single updates object by iterating numeric keys (0,1,2,...)
            const updates: Record<string, any> = {};

            Object.entries(batteriesData).forEach(([key, value]: [string, any]) => {
              const batteryName: string | undefined = value?.batteryName;
              if (!batteryName) return; // skip malformed entries
              if (selectedDropBatteries.includes(batteryName)) {
                updates[`batteries.${key}.assignedBike`] = "None";
                updates[`batteries.${key}.assignedRider`] = "None";
                updates[`batteries.${key}.batteryLocation`] = selectedDropLocation ?? "";
                updates[`batteries.${key}.offTime`] = serverTimestamp();
                return;
              }
            });

            // 3) Validate and push update
            if (Object.keys(updates).length === 0) {
              throw new Error("No matching batteries to update");
            }

            await updateDoc(generalRef, updates);

            // 4) Local cleanup (optional but recommended)
            setSelectedDropBatteries([]);
          })(),
          {
            loading: "Dropping battery...",
            success: <b>Battery is now available to other riders.</b>,
            error: <b>Could not drop batteries.</b>,
          }
        );
      } catch (error) {
        toast.error((error as Error).message || "Unknown error while dropping battery.");
      } finally {
        location.reload();
      }
    }
    const handleDropClose = async () => {
      setOpenDropDialog(false);
    }
    const LoadBattery = async (e: React.FormEvent) => {
      e.preventDefault();
      if (selectedLoadBatteries.length == 0) {
        return toast("Select at least one battery.",
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
      setOpenLoadDialog(true);
    }
    const handleLoadConfirm = async () => {
      setOpenLoadDialog(false);
      try {
        await toast.promise(
          (async () => {
            // 1) Read general document
            const generalRef = doc(db, "general", "general_variables");
            const generalSnap = await getDoc(generalRef);
            if (!generalSnap.exists()) throw new Error("general_variables not found");

            const batteriesData: Record<string, any> = generalSnap.get("batteries") || {};

            // 2) Build a single updates object by iterating numeric keys (0,1,2,...)
            const updates: Record<string, any> = {};

            Object.entries(batteriesData).forEach(([key, value]: [string, any]) => {
              const batteryName: string | undefined = value?.batteryName;
              if (!batteryName) return; // skip malformed entries

              // Priority: if a battery is present in both arrays, treat it as "On"
              if (selectedLoadBatteries.includes(batteryName)) {
                updates[`batteries.${key}.assignedBike`] = user?.currentBike ?? null;
                updates[`batteries.${key}.assignedRider`] = user?.userName ?? null;
                updates[`batteries.${key}.batteryLocation`] = "In Motion";
                updates[`batteries.${key}.offTime`] = serverTimestamp();
                return;
              }
            });

            // 3) Validate and push update
            if (Object.keys(updates).length === 0) {
              throw new Error("No matching batteries to update");
            }

            await updateDoc(generalRef, updates);

            // 4) Local cleanup (optional but recommended)
            setSwapBatteriesOff([]);
            setSwapBatteriesOn([]);
          })(),
          {
            loading: "Loading battery...",
            success: <b>Battery loaded successfully.</b>,
            error: <b>Could not load battery.</b>,
          }
        );
      } catch (error) {
        console.error("SwapBattery error:", error);
        toast.error((error as Error).message || "Unknown error while drooping this battery");
      } finally {
        location.reload();
      }
    }
    const handleLoadClose = () => {
      setOpenLoadDialog(false);
    }
    const SwapBattery = async (e: React.FormEvent) => {
      e.preventDefault();
      if (swapBatteriesOff.length == 0 || swapBatteriesOn.length == 0) {
        return toast("Select a battery from both sides.",
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
      if (selectedSwapLocation === "" || selectedSwapLocation === null) {
        return toast("Select your swap location.",
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
      if (!generalData?.batteries) return;

      setOpenSwapDialog(true);
    }
    const handleSwapConfirm = async () => {
      setOpenSwapDialog(false);
      try {
        await toast.promise(
          (async () => {
            // 1) Read general document
            const generalRef = doc(db, "general", "general_variables");
            const generalSnap = await getDoc(generalRef);
            if (!generalSnap.exists()) throw new Error("general_variables not found");

            const batteriesData: Record<string, any> = generalSnap.get("batteries") || {};

            // 2) Build a single updates object by iterating numeric keys (0,1,2,...)
            const updates: Record<string, any> = {};

            Object.entries(batteriesData).forEach(([key, value]: [string, any]) => {
              const batteryName: string | undefined = value?.batteryName;
              if (!batteryName) return; // skip malformed entries

              // Priority: if a battery is present in both arrays, treat it as "On"
              if (swapBatteriesOn.includes(batteryName)) {
                updates[`batteries.${key}.assignedBike`] = user?.currentBike ?? null;
                updates[`batteries.${key}.assignedRider`] = user?.userName ?? null;
                updates[`batteries.${key}.batteryLocation`] = "In Motion";
                updates[`batteries.${key}.offTime`] = serverTimestamp();
                return;
              }

              if (swapBatteriesOff.includes(batteryName)) {
                updates[`batteries.${key}.assignedBike`] = "None";
                updates[`batteries.${key}.assignedRider`] = "None";
                updates[`batteries.${key}.batteryLocation`] = selectedSwapLocation ?? "";
                updates[`batteries.${key}.offTime`] = serverTimestamp();
                return;
              }
            });

            // 3) Validate and push update
            if (Object.keys(updates).length === 0) {
              throw new Error("No matching batteries to update");
            }

            await updateDoc(generalRef, updates);

            // 4) Local cleanup (optional but recommended)
            setSwapBatteriesOff([]);
            setSwapBatteriesOn([]);
          })(),
          {
            loading: "Swapping batteries...",
            success: <b>Batteries updated successfully.</b>,
            error: <b>Could not swap batteries.</b>,
          }
        );
      } catch (error) {
        console.error("SwapBattery error:", error);
        toast.error((error as Error).message || "Unknown error while swapping batteries");
      } finally {
        location.reload();
      }
    }
    const handleSwapClose = () => {
      setOpenSwapDialog(false);
    }








    {/* we are not clocked in */}
    if (!(user.isClockedIn)) {
      return (
        <div className="clockins-container">
          <div><Toaster /></div>
          <form className="form_container" onSubmit={ClockIn}>
            <div className="logo_container">
              <img className="logo" src={logo} alt="logo" width={150} height={150} />
            </div>
            <div className="title_container">
              <p className="title">Clocking In</p>
              <span className="subtitle">Begin your shift.</span>
            </div>
            <br />
            {
                freeBatteriesCount == 0 && (
                  <label className="input_label" htmlFor="">No more batteries left. Check after a while.</label>
                )
              }
            {
              freeBikesCount == 0 && (
                <label className="input_label" htmlFor="">No more batteries left. Check after a while.</label>
              )
            }
            {
              freeBikesCount > 0 && freeBatteriesCount > 0 && (
                <>
                  <div className="input_container">
                    <table>
                      <thead>
                        <tr>
                          <th><label className="input_label" htmlFor="clockin_bike">Bike</label></th>
                          <th>
                            <select
                              title="Select Bike"
                              className="styled-select"
                              value={selectedBike?.toString() ?? ""}
                              onChange={(e) => setSelectedBike(e.target.value)}
                              >
                              <option value="">Select a bike</option>
                              {Object.entries(generalData?.bikes ?? {})
                                .filter(([, bike]) => bike.isAssigned === false)
                                .map(([bikeName]) => (
                                  <option key={bikeName} value={bikeName}>
                                    {bikeName}
                                  </option>
                              ))}
                              <td>

                              </td>
                            </select>
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td>
                            <label className="input_label" htmlFor="clockin_mileage">Batteries</label>
                          </td>
                          <td>
                            <table className="inner-table">
                              <tbody>
                                
                                {Object.entries(generalData?.batteries ?? {})
                                  .filter(([, battery]) => battery.assignedBike === "None")
                                  .map(([batteryName, battery]) => (
                                    <tr>
                                      <label key={batteryName} style={{ display: "block", marginBottom: "6px" }}>
                                        <input
                                            type="checkbox"
                                            value={battery.batteryName}
                                            checked={selectedBatteries.includes(battery.batteryName)}
                                            onChange={(e) => {
                                              if (e.target.checked) {
                                                if (selectedBatteries.length < 2) {
                                                  setSelectedBatteries([...selectedBatteries, battery.batteryName]);
                                                }
                                              } else {
                                                setSelectedBatteries(
                                                  selectedBatteries.filter((b) => b !== battery.batteryName)
                                                );
                                              }
                                            }}
                                            disabled={
                                              !selectedBatteries.includes(battery.batteryName) &&
                                              selectedBatteries.length >= 2
                                            }
                                          />
                                          <span style={{ marginLeft: "8px" }}>
                                            {battery.batteryName} ({battery.batteryLocation})
                                          </span>
                                      </label>

                                    </tr>
                                ))}

                              </tbody>
                            </table>
                          </td>
                        </tr>

                        <tr>
                          <td>
                              <label className="input_label" htmlFor="clockin_mileage">Mileage</label>
                          </td>
                          <td>
                              <input type="number"
                                className="input_field" 
                                placeholder="0"
                                  value={mileage}
                                  onChange={(e) =>
                                    setMileage(e.target.value)
                                  }
                                  onWheel={e => e.currentTarget.blur()}
                                  title="Clockin Mileage" name="clockin_mileage" id="clockin_mileage" />
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <button title="Clock In" type="submit" className="sign-in_btn" >
                    <span>Clock In</span>
                  </button>
                </>
              )
            }
    
            <div className="separator">
              <hr className="line" />
              <span className="note">Internal Operations</span>
              <hr className="line" />
            </div>
          </form>

          <AlertDialog
            open={openClockInDialog}
            title="Confirm action"
            description="Are you sure you want to clock in?"
            onConfirm={handleClockInConfirm}
            onClose={handleClockInClose}
          />
        </div>
      );
    }

    // if we are clocked in and can load another battery
    if (user.isClockedIn && ourBatteriesCount !== null) {
      return (
        <div className="clockins-container">
          <div><Toaster /></div>

          {/* swap form */}
          {
            ourBatteriesCount > 0 && freeBatteriesCount > 0 && (
              <form className="form_container" onSubmit={SwapBattery}>
                <div className="logo_container">
                  <img className="logo" src={logo} alt="logo" width={150} height={150} />
                </div>
                <div className="title_container">
                  <p className="title">Battery Swaps</p>
                  <span className="subtitle">Modify your shift.</span>
                </div>
                <br />
                <div className="input_container">
                  <table>
                    <thead>
                      <th>Offload</th>
                      <th>Reload</th>
                    </thead>
                    <tbody>
                      <tr>
                        <td>
                          {Object.entries(generalData?.batteries ?? {})
                            .filter(([, battery]) => battery.assignedRider == user.userName)
                              .map(([batteryName, battery]) => (
                                <tr>
                                  <td>
                                    <label key={batteryName} style={{ display: "block", marginBottom: "6px" }}>
                                      <input
                                          type="checkbox"
                                          value={battery.batteryName} // use the field, not the map key
                                          checked={swapBatteriesOff.includes(battery.batteryName)}
                                          onChange={(e) => {
                                            if (e.target.checked) {
                                              if (swapBatteriesOff.length < 2) {
                                                setSwapBatteriesOff([...swapBatteriesOff, battery.batteryName]);
                                              }
                                            } else {
                                              setSwapBatteriesOff(
                                                swapBatteriesOff.filter((b) => b !== battery.batteryName)
                                              );
                                            }
                                          }}
                                          disabled={
                                            !swapBatteriesOff.includes(battery.batteryName) &&
                                            swapBatteriesOff.length >= 1
                                          }
                                        />
                                        <span style={{ marginLeft: "8px" }}>
                                          {battery.batteryName}
                                        </span>
                                    </label>
                                  </td>
                                </tr>
                            ))}
                        </td>
                        <td>
                          {Object.entries(generalData?.batteries ?? {})
                            .filter(([, battery]) => battery.assignedBike === "None")
                              .map(([batteryName, battery]) => (
                                <tr>
                                  <td>
                                    <label key={batteryName} style={{ display: "block", marginBottom: "6px" }}>
                                      <input
                                          type="checkbox"
                                          value={battery.batteryName} // use the field, not the map key
                                          checked={swapBatteriesOn.includes(battery.batteryName)}
                                          onChange={(e) => {
                                            // alert([...selectedBatteries, battery.batteryName]); // now you'll see BK-001, etc.
                                            if (e.target.checked) {
                                              if (swapBatteriesOn.length < 2) {
                                                setSwapBatteriesOn([...swapBatteriesOn, battery.batteryName]);
                                              }
                                            } else {
                                              setSwapBatteriesOn(
                                                swapBatteriesOn.filter((b) => b !== battery.batteryName)
                                              );
                                            }
                                          }}
                                          disabled={
                                            !swapBatteriesOn.includes(battery.batteryName) &&
                                            swapBatteriesOn.length >= 1
                                          }
                                        />
                                        <span style={{ marginLeft: "8px" }}>
                                          {battery.batteryName}
                                        </span>
                                    </label>
                                  </td>
                                </tr>
                            ))}
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <label className="input_label" htmlFor="clockin_mileage">Location</label>
                        </td>
                        <td>
                          <select
                            title="Select Location"
                            className="styled-select"
                            value={selectedSwapLocation?.toString() ?? ""}
                            onChange={(e) => setSelectedSwapLocation(e.target.value)}
                            >
                            <option value="">Select location</option>
                            {Object.entries(generalData?.destinations ?? {})
                              .map(([key, value]) => (
                                <option key={key} value={value as string}>
                                  {value as string}
                                </option>
                              ))}

                          </select>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <button title="Swap Battery" type="submit" className="sign-in_btn" >
                  <span>Swap Battery</span>
                </button>
        
                <div className="separator">
                  <hr className="line" />
                  <span className="note">Internal Operations</span>
                  <hr className="line" />
                </div>
              </form>
            )
          }

          {/* load form */}
          {
            ourBatteriesCount < 2 && freeBatteriesCount > 1 && (
              <form className="form_container" onSubmit={LoadBattery}>
                <div className="logo_container">
                  <img className="logo" src={logo} alt="logo" width={150} height={150} />
                </div>
                <div className="title_container">
                  <p className="title">Battery Loading</p>
                  <span className="subtitle">Modify your shift.</span>
                </div>
                <br />
                <div className="input_container">
                  <table>
                    <tbody>
                      <div className="input_container">
                        <label className="input_label" htmlFor="bike_field">Batteries</label>
                      </div>
                      <div>
                        <table>
                          <tbody>
                            {Object.entries(generalData?.batteries ?? {})
                              .filter(([, battery]) => battery.assignedBike === "None")
                              .map(([batteryName, battery]) => (
                                <tr>
                                  <td>
                                    <label key={batteryName} style={{ display: "block", marginBottom: "6px" }}>
                                      <input
                                          type="checkbox"
                                          value={battery.batteryName} // use the field, not the map key
                                          checked={selectedLoadBatteries.includes(battery.batteryName)}
                                          onChange={(e) => {
                                            // alert([...selectedBatteries, battery.batteryName]); // now you'll see BK-001, etc.
                                            if (e.target.checked) {
                                              if (selectedLoadBatteries.length < 2) {
                                                setSelectedLoadBatteries([...selectedLoadBatteries, battery.batteryName]);
                                              }
                                            } else {
                                              setSelectedLoadBatteries(
                                                selectedLoadBatteries.filter((b) => b !== battery.batteryName)
                                              );
                                            }
                                          }}
                                          disabled={
                                            !selectedLoadBatteries.includes(battery.batteryName) &&
                                            selectedLoadBatteries.length >= 1
                                          }
                                        />
                                        <span style={{ marginLeft: "8px" }}>
                                          {battery.batteryName} ({battery.batteryLocation})
                                        </span>
                                    </label>
                                  </td>

                                </tr>
                            ))}
                          </tbody>
                        </table>

                      </div>
                    </tbody>
                  </table>
                </div>

                <button title="Load Battery" type="submit" className="sign-in_btn" >
                  <span>Load Battery</span>
                </button>
        
                <div className="separator">
                  <hr className="line" />
                  <span className="note">Internal Operations</span>
                  <hr className="line" />
                </div>
              </form>
            )
          }

          {/* drop battery form */}
          {
            ourBatteriesCount > 0 && (
              <form className="form_container" onSubmit={DropBattery}>
                <div className="logo_container">
                  <img className="logo" src={logo} alt="logo" width={150} height={150} />
                </div>
                <div className="title_container">
                  <p className="title">Battery Drops</p>
                  <span className="subtitle">Modify your shift.</span>
                </div>
                <br />
                <div className="input_container">
                  <table>
                    <tbody>
                      <tr>
                        <td><label className="input_label" htmlFor="clockin_mileage">Batteries</label></td>
                        <td>
                          {Object.entries(generalData?.batteries ?? {})
                              .filter(([, battery]) => battery.assignedRider == user.userName)
                              .map(([batteryName, battery]) => (
                                <tr>
                                  <td>
                                    <label key={batteryName} style={{ display: "block", marginBottom: "6px" }}>
                                      <input
                                          type="checkbox"
                                          value={battery.batteryName} // use the field, not the map key
                                          checked={selectedDropBatteries.includes(battery.batteryName)}
                                          onChange={(e) => {
                                            // alert([...selectedBatteries, battery.batteryName]); // now you'll see BK-001, etc.
                                            if (e.target.checked) {
                                              if (selectedDropBatteries.length < 2) {
                                                setSelectedDropBatteries([...selectedDropBatteries, battery.batteryName]);
                                              }
                                            } else {
                                              setSelectedDropBatteries(
                                                selectedDropBatteries.filter((b) => b !== battery.batteryName)
                                              );
                                            }
                                          }}
                                          disabled={
                                            !selectedDropBatteries.includes(battery.batteryName) &&
                                            selectedDropBatteries.length >= 1
                                          }
                                        />
                                        <span style={{ marginLeft: "8px" }}>
                                          {battery.batteryName}
                                        </span>
                                    </label>
                                  </td>

                                </tr>
                            ))}
                        </td>
                      </tr>

                      <tr>
                        <td>
                          <label className="input_label" htmlFor="clockin_mileage">Location</label>
                        </td>
                        <td>
                          <select
                            title="Select Location"
                            className="styled-select"
                            value={selectedDropLocation?.toString() ?? ""}
                            onChange={(e) => setSelectedDropLocation(e.target.value)}
                            >
                            <option value="">Select location</option>
                            {Object.entries(generalData?.destinations ?? {})
                              .map(([key, value]) => (
                                <option key={key} value={value as string}>
                                  {value as string}
                                </option>
                              ))}

                          </select>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <button title="Drop Battery" type="submit" className="sign-in_btn" >
                  <span>Drop Battery</span>
                </button>
        
                <div className="separator">
                  <hr className="line" />
                  <span className="note">Internal Operations</span>
                  <hr className="line" />
                </div>
              </form>
            )
          }

          <AlertDialog
            open={openSwapDialog}
            title="Confirm action"
            description="Are you sure you want to swap these batteries?"
            onConfirm={handleSwapConfirm}
            onClose={handleSwapClose}
          />
          <AlertDialog
            open={openLoadDialog}
            title="Confirm action"
            description="Are you sure you want to load this battery?"
            onConfirm={handleLoadConfirm}
            onClose={handleLoadClose}
          />
          <AlertDialog
            open={openDropDialog}
            title="Confirm action"
            description="Are you sure you want to drop this battery?"
            onConfirm={handleDropConfirm}
            onClose={handleDropClose}
          />

        </div>
      )
    }

}
