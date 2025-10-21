/* eslint-disable @typescript-eslint/no-unused-vars */
import { useEffect, useState } from "react";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import "firebase/compat/firestore";
import { fetchGeneralVariables, fetchUser, type GeneralVariables, type UserData } from "../services/userService";
import PrimaryLoadingFragment from "../assets/PrimaryLoading";
import NoUserFound from "../assets/NoUserFound";
import CompanyPaused from '../assets/CompanyState';
import logo from "../assets/logo2.png";
import { Toaster } from "react-hot-toast";
import toast from 'react-hot-toast';
import { doc, setDoc, getDoc, updateDoc, serverTimestamp, Timestamp } from "firebase/firestore";
import AlertDialog from "../assets/Dialog";
import { auth, db } from "../assets/Firebase";
import { formatCurrency } from "../assets/CurrencyFormatter";
import { formatElapsedTime, getDateKey, getDayOfWeek, getWeekName } from "../assets/publicFunctions";

export default function Clockout() {
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<UserData | null>(null);
  const [generalData, setGeneralData] = useState<GeneralVariables | null>(null);
  const [openClockOutDialog, setOpenClockOutDialog] = useState(false);
  const [uid, setUid] = useState<string | null>(null);
  const [currentBike, setCurrentBike] = useState<string>("");

  // from filling the form
  const [accTarget, setAccTarget] = useState<string>("");
  const [numTarget, setNumTarget] = useState<number>(0);
  const [grossIncome, setGrossIncome] = useState<string>("");
  const [commission, setCommission] = useState<string>("");
  const [todaysInAppBalance, setTodaysInAppBalance] = useState<string>("");
  const [prevInAppBalance, setPrevInAppBalance] = useState<string>("");
  const [bsExpense, setBsExpense] = useState<string>("");
  const [bsExpenseEnabled, setBsExpenseEnabled] = useState(false);
  const [dbExpense, setDbExpense] = useState<string>("");
  const [dbExpenseEnabled, setDbExpenseEnabled] = useState(false);
  const [lunchExpense, setLunchExpense] = useState<string>("");
  const [lunchExpenseEnabled, setLunchExpenseEnabled] = useState(false);
  const [policeExpense, setPoliceExpense] = useState<string>("");
  const [policeExpenseEnabled, setPoliceExpenseEnabled] = useState(false);
  const [aOBExpense, setAOBExpense] = useState<string>("");
  const [aOBExpenseEnabled, setAobExpenseEnabled] = useState(false);
  const [otherExpenseDescr, setOtherExpenseDescr] = useState<string>("");
  const [mileage, setMileage] = useState<string>("");
  const [netIncome, setNetIncome] = useState<number>(0);
  const [selectedClockOutLocation, setSelectedClockOutLocation] = useState<string>("");

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

      setCommission(generalData?.commissionPercentage?.toString() ?? "0");
      setPrevInAppBalance(userData?.currentInAppBalance?.toString() ?? "0");
      setCurrentBike(userData?.currentBike ?? "None");

    }

    loadUser();
  }, [uid]);

  useEffect(() => {
    if (user && user.dailyTarget !== undefined && user.sundayTarget !== undefined) {
      const today = new Date();
      const dayIndex = today.getDay(); // 0 = Sunday, 1 = Monday, ... 6 = Saturday

      const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
      const dayName = days[dayIndex];
      if (dayName == "Sunday") {
        setAccTarget(formatCurrency(user.sundayTarget).toString());
        setNumTarget(user.sundayTarget);
      } else {
        setAccTarget(formatCurrency(user.dailyTarget).toString());
        setNumTarget(user.dailyTarget);
      }
    }
  }, [user]);

  // compute net income onChange of literally every thing
  useEffect(() => {
    const netIncome = (Number(grossIncome) || 0) // gross
      - ((Number(commission) || 0) / 100 * (Number(grossIncome) || 0)) // commission
      + ((Number(prevInAppBalance) || 0) - (Number(todaysInAppBalance) || 0)) // in app balance diff

      // expenses
      - ((bsExpenseEnabled ? (Number(bsExpense) || 0) : 0)
      + (dbExpenseEnabled ? (Number(dbExpense) || 0) : 0)
      + (lunchExpenseEnabled ? (Number(lunchExpense) || 0) : 0)
      + (policeExpenseEnabled ? (Number(policeExpense) || 0) : 0)
      + (aOBExpenseEnabled ? (Number(aOBExpense) || 0) : 0))
    setNetIncome(netIncome);
  }, [grossIncome, commission, todaysInAppBalance, prevInAppBalance, bsExpense, bsExpenseEnabled, dbExpense, dbExpenseEnabled, lunchExpense, lunchExpenseEnabled, policeExpense, policeExpenseEnabled, aOBExpense, aOBExpenseEnabled]);
  
  
  
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

  const ClockOut = async (e: React.FormEvent) => {
    e.preventDefault();
    if (mileage.trim() === "" || grossIncome.trim() === "" || selectedClockOutLocation?.trim() === "") {
      return toast("Gross income, Mileage and Location are compulsory.", {
        icon: "❗",
        style: {
          borderRadius: "10px",
          background: "#fff",
          color: "red",
        },
      });
    }
    if (Number(mileage) < (user?.clockinMileage || 0)) {
      return toast("Clockout mileage has to be higher that clockin mileage.", {
        icon: "❗",
        style: {
          borderRadius: "10px",
          background: "#fff",
          color: "red",
        },
      });
    }
    if (aOBExpenseEnabled && otherExpenseDescr.trim() === "") {
      return toast("Describe your other expense better.", {
        icon: "❗",
        style: {
          borderRadius: "10px",
          background: "#fff",
          color: "red",
        },
      });
    }
    setOpenClockOutDialog(true);
  }

  const handleClockOutConfirm = async () => {
    setOpenClockOutDialog(false);
    clockOut()
  }
  const handleClockOutClose = () => {
    setOpenClockOutDialog(false);
  }

  const buildExpensesMap = () => {
    const expenses: Record<string, number> = {};

    if (bsExpenseEnabled && bsExpense.trim() !== "") {
      expenses["Battery Swap"] = parseFloat(bsExpense) || 0;
    }

    if (dbExpenseEnabled && dbExpense.trim() !== "") {
      expenses["Data Bundles"] = parseFloat(dbExpense) || 0;
    }

    if (lunchExpenseEnabled && lunchExpense.trim() !== "") {
      expenses["Lunch"] = parseFloat(lunchExpense) || 0;
    }

    if (policeExpenseEnabled && policeExpense.trim() !== "") {
      expenses["Police"] = parseFloat(policeExpense) || 0;
    }

    if (aOBExpenseEnabled && aOBExpense.trim() !== "") {
      expenses[otherExpenseDescr] = parseFloat(aOBExpense) || 0;
    }

    return expenses;
  };


  const clockOut = async () => {
    const uid = auth.currentUser?.uid;
    if (!uid) throw new Error("User not authenticated");

    const userRef = doc(db, "users", uid);
    const dateKey = getDateKey();

    try {
      await toast.promise(
        (async () => {
          // 1. Update user profile fields
          const userSnap = await getDoc(userRef);

          if (!userSnap.exists()) return;
          const userData = userSnap.data();
          const currentMonth = new Date().toLocaleString("en-US", { month: "long" });
          const existingNetIncomes = userData.netIncomes || {};
          const currentMonthIncome = Number(existingNetIncomes[currentMonth] || 0);
          existingNetIncomes[currentMonth] = currentMonthIncome + netIncome;

          await updateDoc(userRef, {
            todaysInAppBalance: Number(todaysInAppBalance) || 0,
            isWorkingOnSunday: false,
            isClockedIn: false,
            netClockedLastly: netIncome,
            pendingAmount: (user?.pendingAmount || 0) + netIncome,
            lastClockDate: serverTimestamp(),
            currentBike: "None",
            netIncomes: existingNetIncomes
          });
  
          // 2. Update clockout entry inside user profile
          await updateDoc(userRef, {
            [`clockouts.${dateKey}`]: {
              grossIncome: parseFloat(grossIncome),
              todaysInAppBalance: parseFloat(todaysInAppBalance),
              previousInAppBalance: parseFloat(prevInAppBalance),
              inAppDifference: parseFloat(todaysInAppBalance) - parseFloat(prevInAppBalance),
              expenses: buildExpensesMap(),
              netIncome: parseFloat(netIncome.toString()),
              clockinMileage: user?.clockinMileage || 0,
              clockoutMileage: parseFloat(mileage),
              mileageDifference: parseFloat(mileage) - (user?.clockinMileage || 0),
              posted_at: serverTimestamp(),
              timeElapsed: formatElapsedTime(
                user?.clockinTime instanceof Timestamp ? user.clockinTime.toDate() : new Date(),
                new Date()
              )
  
            },
          });
  
          // 3. Write into deviations/{weekName}/{userName}/{dayOfWeek}
          const now = new Date();
          const weekName = getWeekName(now);
          const dayOfWeek = getDayOfWeek(now);
  
          const deviationsRef = doc(db, "deviations", weekName);
          const userName = user?.userName || "Unknown";
  
          await setDoc(
            deviationsRef,
            {
              [userName]: {
                [dayOfWeek]: {
                  grossDeviation: parseFloat(grossIncome) - numTarget,
                  grossIncome: parseFloat(grossIncome),
                  netDeviation: parseFloat(netIncome.toString()) - parseFloat(numTarget.toString()),
                  netGrossDifference: parseFloat(grossIncome) - netIncome,
                  netIncome: parseFloat(netIncome.toString()),
                },
              },
            },
            { merge: true }
          );
  
          // 4. Update bike assignment in general/general_variables
          const generalRef = doc(db, "general", "general_variables");
          await updateDoc(generalRef, {
            [`bikes.${user?.currentBike}.assignedRider`]: "None",
            [`bikes.${user?.currentBike}.isAssigned`]: false,
          });
  
          // update any batteries that we have
          const generalSnap = await getDoc(generalRef);
          if (generalSnap.exists()) {
            const data = generalSnap.data();
            const batteries = data?.batteries || {};
  
            const updates: Record<string, any> = {};
            Object.entries(batteries).forEach(([key, battery]: [string, any]) => {
              if (battery.assignedRider === userName) {
                updates[`batteries.${key}.assignedBike`] = "None";
                updates[`batteries.${key}.assignedRider`] = "None";
                updates[`batteries.${key}.offTime`] = serverTimestamp();
                updates[`batteries.${key}.batteryLocation`] = selectedClockOutLocation;
              }
            });
  
            if (Object.keys(updates).length > 0) {
              await updateDoc(generalRef, updates);
            }
          }
        })(),
        {
          loading: "Clocking out...",
          success: <b>Clockout saved.</b>,
          error: <b>Could not clock out.</b>,
        }
      );
    } catch (error) {
      return toast(`A critical issue occured. ${error}`, {
        icon: "❗",
        style: {
          borderRadius: "10px",
          background: "#fff",
          color: "red",
        },
      });
    }
    finally {
      location.reload();
    }
  }

  return (
    <div className="clockouts-container">
      <div><Toaster /></div>
      <form className="form_container" onSubmit={ClockOut}>
        <div className="logo_container">
          <img className="logo" src={logo} alt="logo" width={150} height={150} />
        </div>
        <div className="title_container">
          <p className="title">Clocking Out</p>
          <span className="subtitle">End your shift.</span>
        </div>
        <br />

        {
          !user.isClockedIn && (
            <p className="clockinFirst">You will need to clock in first</p>
          )
        }

        {
          user.isClockedIn && (
            <div>
              <table>
                <thead>
                  <tr>
                    <th>Parameter</th>
                    <th>Value</th>
                  </tr>
                </thead>

                <tbody>

                  {/* targets */}
                  <tr>
                    <td><label className="input_label" htmlFor="acc_target">Target (KSh.)</label></td>
                    <td><label className="input_label" htmlFor="acc_target">{accTarget}</label></td>
                  </tr>

                  {/* target deviations */}
                  <tr>
                    <td><label className="input_label" htmlFor="acc_deviation">Deviation from Target</label></td>
                    <td>
                      {(() => {
                        const deviation = Number(grossIncome) - numTarget;
                        let color = "black"; // default

                        if (deviation > 250) {
                          color = "green";
                        } else if (deviation < 0) {
                          color = "red";
                        } else {
                          color = "orange";
                        }

                        return (
                          <label
                            className="input_label"
                            htmlFor="acc_deviation"
                            style={{ color }}
                          >
                            {formatCurrency(deviation)}
                          </label>
                        );
                      })()}
                    </td>
                  </tr>

                  {/* gross */}
                  <tr>
                    <td><label className="input_label" htmlFor="clockout_gross">Gross Income (KSh.)</label></td>
                    <td>
                      <input type="number"
                            className="input_field" 
                            placeholder="0"
                              value={grossIncome}
                              onChange={(e) =>
                                setGrossIncome(e.target.value)
                              }
                              onWheel={e => e.currentTarget.blur()}
                              title="Clock Out Gross Income" name="clockout_gross" id="clockout_gross" />
                    </td>
                  </tr>

                  {/* commission */}
                  <tr>
                    <td><label className="input_label" htmlFor="commission">Commission</label></td>
                    <td>
                      <input type="number"
                              className="input_field" 
                              readOnly
                              placeholder="0"
                                value={generalData?.commissionPercentage}
                                onChange={(e) =>
                                  setCommission(e.target.value)
                                }
                                onWheel={e => e.currentTarget.blur()}
                                title="Commission" name="commission" id="commission" />

                    </td>
                  </tr>

                  {/* today's in app bal */}
                  <tr>
                    <td><label className="input_label" htmlFor="in_app_bal">Today's In-App Balance (Ksh.)</label></td>
                    <td>
                      <input type="number"
                            className="input_field" 
                            placeholder="0"
                              value={todaysInAppBalance}
                              onChange={(e) =>
                                setTodaysInAppBalance(e.target.value)
                              }
                              onWheel={e => e.currentTarget.blur()}
                              title="In App Balance" name="in_app_bal" id="in_app_bal" />
                    </td>
                  </tr>

                  {/* previous in app bal */}
                  <tr>
                    <td><label className="input_label" htmlFor="prev_bal">Previous In-App Balance (KSh.)</label></td>
                    <td>
                      <input type="number"
                              className="input_field" 
                              placeholder="0"
                                value={user.currentInAppBalance}
                                onChange={(e) =>
                                  setPrevInAppBalance(e.target.value)
                                }
                                onWheel={e => e.currentTarget.blur()}
                                title="Previous In App Balance" name="prev_bal" id="prev_bal"
                                readOnly/>
                    </td>
                  </tr>

                  {/* expenses */}
                  <tr>
                    <td><label className="input_label" htmlFor="">Expenses (KSh.)</label></td>
                    <td>
                      <table>
                        <tbody className="inner-table">

                          {/* bs */}
                          <tr>
                            <td>
                              <input
                                type="checkbox"
                                name="bsExpense"
                                id="bsExpense"
                                title="Battery Swap"
                                checked={bsExpenseEnabled}
                                onChange={(e) => setBsExpenseEnabled(e.target.checked)}
                              />
                            </td>
                            <td>
                              <label className="input_label" htmlFor="bsExpense">Battery Swap</label>
                            </td>
                            <td>
                              <input
                                type="number"
                                className="input_field"
                                placeholder="0"
                                value={bsExpense}
                                disabled={!bsExpenseEnabled}
                                onChange={(e) => setBsExpense(e.target.value)}
                                onWheel={(e) => e.currentTarget.blur()} // prevent scroll changing value
                                title="Battery Swap Expense"
                                name="bsExpenseInput"
                                id="bsExpenseInput"
                              />
                            </td>
                          </tr>

                          {/* db */}
                          <tr>
                            <td>
                              <input
                                type="checkbox"
                                name="dbExpense"
                                id="dbExpense"
                                title="Data Bundles"
                                checked={dbExpenseEnabled}
                                onChange={(e) => setDbExpenseEnabled(e.target.checked)}
                              />
                            </td>
                            <td>
                              <label className="input_label" htmlFor="dbExpense">Data Bundles</label>
                            </td>
                            <td>
                              <input
                                type="number"
                                className="input_field"
                                placeholder="0"
                                value={dbExpense}
                                disabled={!dbExpenseEnabled}
                                onChange={(e) => setDbExpense(e.target.value)}
                                onWheel={(e) => e.currentTarget.blur()} // prevent scroll changing value
                                title="Data Bundles Expense"
                                name="dbExpenseInput"
                                id="dbExpenseInput"
                              />
                            </td>
                          </tr>

                          {/* lunch */}
                          <tr>
                            <td>
                              <input
                                type="checkbox"
                                name="lunchExpense"
                                id="lunchExpense"
                                title="Lunch"
                                checked={lunchExpenseEnabled}
                                onChange={(e) => setLunchExpenseEnabled(e.target.checked)}
                              />
                            </td>
                            <td>
                              <label className="input_label" htmlFor="lunchExpense">Lunch</label>
                            </td>
                            <td>
                              <input
                                type="number"
                                className="input_field"
                                placeholder="0"
                                value={lunchExpense}
                                disabled={!lunchExpenseEnabled}
                                onChange={(e) => setLunchExpense(e.target.value)}
                                onWheel={(e) => e.currentTarget.blur()} // prevent scroll changing value
                                title="Lunch Expense"
                                name="lunchExpenseInput"
                                id="lunchExpenseInput"
                              />
                            </td>
                          </tr>

                          {/* police */}
                          <tr>
                            <td>
                              <input
                                type="checkbox"
                                name="policeExpense"
                                id="policeExpense"
                                title="Police"
                                checked={policeExpenseEnabled}
                                onChange={(e) => setPoliceExpenseEnabled(e.target.checked)}
                              />
                            </td>
                            <td>
                              <label className="input_label" htmlFor="policeExpense">Police</label>
                            </td>
                            <td>
                              <input
                                type="number"
                                className="input_field"
                                placeholder="0"
                                value={policeExpense}
                                disabled={!policeExpenseEnabled}
                                onChange={(e) => setPoliceExpense(e.target.value)}
                                onWheel={(e) => e.currentTarget.blur()} // prevent scroll changing value
                                title="Police Expense"
                                name="policeExpenseInput"
                                id="policeExpenseInput"
                              />
                            </td>
                          </tr>

                          {/* aob */}
                          <tr>
                            <td>
                              <input
                                type="checkbox"
                                name="aOBExpense"
                                id="aOBExpense"
                                title="Other"
                                checked={aOBExpenseEnabled}
                                onChange={(e) => setAobExpenseEnabled(e.target.checked)}
                              />
                            </td>
                            <td>
                              <label className="input_label" htmlFor="aOBExpense">Other</label>
                            </td>
                            <td>
                              <input
                                type="number"
                                className="input_field"
                                placeholder="0"
                                value={aOBExpense}
                                disabled={!aOBExpenseEnabled}
                                onChange={(e) => setAOBExpense(e.target.value)}
                                onWheel={(e) => e.currentTarget.blur()} // prevent scroll changing value
                                title="Other Expense"
                                name="otherExpenseInput"
                                id="otherExpenseInput"
                              />
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </td>
                  </tr>

                  {/* other expense */}
                  {
                    aOBExpenseEnabled && (
                      <tr>
                        <td><label className="input_label" htmlFor="aob_descr">Other Expense</label></td>
                        <td>
                          <textarea placeholder="Describe your expense"
                            value={otherExpenseDescr}
                            onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) =>
                              setOtherExpenseDescr(e.target.value)
                            }
                          title="Description" name="description_field-description" className="input_field" id="aob_descr" rows={4} />
                        </td>
                    </tr>
                    )
                  }

                  {/* mileage */}
                  <tr>
                    <td><label className="input_label" htmlFor="clockout_mileage">Mileage</label></td>
                    <td>
                      <input type="number"
                          className="input_field" 
                          placeholder="0"
                            value={mileage}
                            onChange={(e) =>
                              setMileage(e.target.value)
                            }
                            onWheel={e => e.currentTarget.blur()}
                            title="Clockout Mileage" name="clockout_mileage" id="clockout_mileage" />
                    </td>
                  </tr>

                  {/* location */}
                  <tr>
                    <td><label className="input_label" htmlFor="location">Location</label></td>
                    <td>
                      <select
                            title="Select Location"
                            className="styled-select"
                            value={selectedClockOutLocation?.toString() ?? ""}
                            onChange={(e) => setSelectedClockOutLocation(e.target.value)}
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

                  {/* net income */}
                  <tr>
                    <td><label className="input_label" htmlFor="">Computed Net (KSh.)</label></td>
                    <td><label className="input_label" htmlFor="">{formatCurrency(netIncome)}</label></td>
                  </tr>
                </tbody>
              </table>

              <button title="Clock Out" type="submit" className="sign-in_btn" >
                <span>Clock Out</span>
              </button>

            </div>
          )
        }

        <div className="separator">
          <hr className="line" />
          <span className="note">Internal Operations</span>
          <hr className="line" />
        </div>
      </form>

      <AlertDialog
        open={openClockOutDialog}
        title="Confirm action"
        description="Are you sure you want to clock in?"
        onConfirm={handleClockOutConfirm}
        onClose={handleClockOutClose}
      />
    </div>
  );
}
