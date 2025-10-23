/* eslint-disable @typescript-eslint/no-unused-vars */
import toast, { Toaster } from "react-hot-toast";
import logo from "../assets/logo2.png";
import { useEffect, useState } from "react";
import PrimaryLoadingFragment from "../assets/PrimaryLoading";
import { fetchGeneralVariables, fetchUser, type GeneralVariables, type UserData } from "../services/userService";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import { formatCurrency } from '../assets/CurrencyFormatter';
import { doc, setDoc, getDoc, updateDoc, serverTimestamp, Timestamp } from "firebase/firestore";
import NoUserFound from "../assets/NoUserFound";
import AlertDialog from "../assets/Dialog";
import { auth, db } from "../assets/Firebase";
import { getDateKey } from "../assets/publicFunctions";

export default function Corrections() {
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<UserData | null>(null);
  const [generalData, setGeneralData] = useState<GeneralVariables | null>(null);
  const [uid, setUid] = useState<string | null>(null);
  const [grossIncome, setGrossIncome] = useState<string | null>(null);
  const [commission, setCommission] = useState<number | null>(null);
  const [todaysInAppBalance, setTodaysInAppBalance] = useState<string>("");
  const [prevInAppBalance, setPrevInAppBalance] = useState<number | null>(null);
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
  const [netIncome, setNetIncome] = useState<number>(0);
  const [openCorrectionsDialog, setOpenCorrectionsDialog] = useState(false);
  const [dateOptions, setDateOptions] = useState<string[]>([]);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [accTarget, setAccTarget] = useState<number>(0);
  // when date selection changes
  const [dayOfWeek, setDayOfWeek] = useState<string>("");
  const [weekRange, setWeekRange] = useState<string>("");



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
      const generalData = await fetchGeneralVariables();

      setUser(userData);
      setGeneralData(generalData);
      setLoading(false);
      setCommission(generalData?.commissionPercentage || 0);
      setAccTarget(userData?.dailyTarget || 0);
    }

    loadUser();
  }, [uid]);

  useEffect(() => {
    if (!user) return;

    const requirementsMap = user.requirements;
    if (!requirementsMap || typeof requirementsMap !== "object") {
      console.warn("No requirements found.");
      setDateOptions([]); // optional: keep state for dates
      return;
    }

    const dates = Object.values(requirementsMap)
      .map((value: any) => value?.date)
      .filter((date: string | undefined): date is string => !!date)
      .sort((a, b) => b.localeCompare(a)); // descending order

    if (dates.length === 0) {
      console.warn("No requirement dates found.");
      setDateOptions([]);
      return;
    }

    setDateOptions(dates);
  }, [user]);

  // Handle selection
  const handleDateChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const selected = e.target.value;
    setSelectedDate(selected);

    if (!user || !user.requirements) return;

    const requirementsMap = user.requirements;
    const matchedEntry = Object.values(requirementsMap).find(
      (req: any) => req.date === selected
    ) as { appBalance?: number; dayOfWeek?: string; weekRange?: string } | undefined;

    if (matchedEntry) {
      setPrevInAppBalance(matchedEntry.appBalance ?? null);
      setDayOfWeek(matchedEntry.dayOfWeek ?? "");
      setWeekRange(matchedEntry.weekRange ?? "");
    } else {
      // reset if none found
      setPrevInAppBalance(null);
      setDayOfWeek("");
      setWeekRange("");
      setSelectedDate(null);
    }
  };

  // net income
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

  function RectifyClockout(e: any) {
    e.preventDefault();
    // rectify clockout logic here
    if (!selectedDate) {
      return toast("Select a date first.", {
        icon: "❗",
        style: {
          borderRadius: "10px",
          background: "#fff",
          color: "red",
        },
      });
    }
    if (!grossIncome) {
      return toast("Gross income is invalid.", {
        icon: "❗",
        style: {
          borderRadius: "10px",
          background: "#fff",
          color: "red",
        },
      });
    }

    setOpenCorrectionsDialog(true);
  }

  function handleCorrectionsConfirm() {
    // handle corrections confirm logic here
    setOpenCorrectionsDialog(false);
    clockOut();
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
              [`clockouts.${selectedDate}`]: {
                grossIncome: parseFloat(grossIncome || "0"),
                todaysInAppBalance: parseFloat(todaysInAppBalance),
                previousInAppBalance: parseFloat(prevInAppBalance?.toString() || "0"),
                inAppDifference: parseFloat(todaysInAppBalance) - parseFloat(prevInAppBalance?.toString() || "0"),
                expenses: buildExpensesMap(),
                netIncome: parseFloat(netIncome.toString()),
                clockinMileage: 0,
                clockoutMileage: 0,
                mileageDifference: 0,
                posted_at: serverTimestamp(),
                timeElapsed: "Nil"
              },
            });
    
            // 3. Write into deviations/{weekName}/{userName}/{dayOfWeek}
            const deviationsRef = doc(db, "deviations", weekRange);
            const userName = user?.userName || "Unknown";
            await setDoc(
              deviationsRef,
              {
                [userName]: {
                  [dayOfWeek]: {
                    grossDeviation: parseFloat(grossIncome || "0") - accTarget,
                    grossIncome: parseFloat(grossIncome || "0"),
                    netDeviation: parseFloat(netIncome.toString()) - parseFloat(accTarget.toString()),
                    netGrossDifference: parseFloat(grossIncome || "0") - netIncome,
                    netIncome: parseFloat(netIncome.toString()),
                  },
                },
              },
              { merge: true }
            );
    
            // 4. no dropping of bikes
    
            // 5. no dropping of batteries
          })(),
          {
            loading: "Overwriting...",
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

  function handleCorrectionsClose() {
    setOpenCorrectionsDialog(false);
  }


  if (user) {
    return (
      <div className="corrections-container">
        <div className="clockouts-container">
        <div><Toaster /></div>
        <form className="form_container" onSubmit={RectifyClockout}>
          <div className="logo_container">
            <img className="logo" src={logo} alt="logo" width={150} height={150} />
          </div>
          <div className="title_container">
            <p className="title">Corrections</p>
            <span className="subtitle">Rectify a previous clockout.</span>
          </div>
          <br />
  
          {
            user && user.isClockedIn && (
              <p className="clockinFirst">Please clock out for today first</p>
            )
          }
  
          {
            user && !user.isClockedIn && (
              <div>

                <table>
                  <thead>
                    <tr>
                      <th>Parameter</th>
                      <th>Value</th>
                    </tr>
                  </thead>
  
                  <tbody>
                    {/* the date */}
                    <tr>
                      <td><label className="input_label" htmlFor="acc_target">Date to correct</label></td>
                      <select
                        value={selectedDate || ""}
                        title="Select a date"
                        className="styled-select"
                        onChange={handleDateChange}
                      >
                        <option value="">Select a date</option>
                        {dateOptions.map((date, index) => (
                          <option key={index} value={date}>
                            {date}
                          </option>
                        ))}
                      </select>
                    </tr>
  
                    {/* targets */}
                    <tr>
                      <td><label className="input_label" htmlFor="acc_target">Target (KSh.)</label></td>
                      <td><label className="input_label" htmlFor="acc_target">{formatCurrency(Number(user.dailyTarget))}</label></td>
                    </tr>
  
                    {/* target deviations */}
                    <tr>
                      <td><label className="input_label" htmlFor="acc_deviation">Deviation from Target</label></td>
                      <td>
                        {(() => {
                          const deviation = Number(grossIncome) - (user.dailyTarget || 0);
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
                                value={grossIncome || ""}
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
                          value={commission || ""}
                          onWheel={e => e.currentTarget.blur()}
                          title="Commission" name="commission" id="commission" />
  
                      </td>
                    </tr>
  
                    {/* today's in app bal */}
                    <tr>
                      <td><label className="input_label" htmlFor="in_app_bal">Day's In-App Balance (Ksh.)</label></td>
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
                      <td><label className="input_label" htmlFor="prev_bal">Prior In-App Balance (KSh.)</label></td>
                      <td>
                        <input type="number"
                          className="input_field" 
                          placeholder="0"
                            value={prevInAppBalance || ""}
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
          open={openCorrectionsDialog}
          title="Confirm action"
          description="Are you sure you want to post this correction?"
          onConfirm={handleCorrectionsConfirm}
          onClose={handleCorrectionsClose}
        />
      </div>
      </div>
    );
    
  }
}
