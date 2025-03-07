import Button1 from "@/assets/utilities/button1";
import checkAndUpdateUnpushedAmount from "@/assets/utilities/check_increment_dates";
import CheckIfThisUserIsStillLoggedIn from "@/assets/utilities/check_login_status";
import CheckBox from "@/assets/utilities/checkbox";
import db, { auth } from "@/assets/utilities/firebase_file";
import * as Device from 'expo-device';
// import CheckBox from "@/utilities/checkbox";
// import db, { auth } from "@/utilities/firebase";
import { Ionicons } from "@expo/vector-icons";
import { useFocusEffect } from "expo-router";
import { signOut } from "firebase/auth";
import { collection, doc, getDoc, getDocs, increment, setDoc, updateDoc } from "firebase/firestore";
import { useCallback, useEffect, useState } from "react";
import { KeyboardAvoidingView, Modal, Text, View, ScrollView, Platform, TextInput, StyleSheet, ActivityIndicator, Button, Alert } from 'react-native';
// import DeviceInfo from 'react-native-device-info';

export default function UserClockOut() {
    const [loading, setLoading] = useState<boolean>(false);
    const [posting, setPosting] = useState<boolean>(false);
    const [deviceInfo, setDeviceInfo] = useState<string>("");
    const [grossIncome, setGrossIncome] = useState<number | null>(0);
    const [commissionConstant, setCommissionConstant] = useState<number>(0);
    const [netIncome, setNetIncome] = useState<number>(0);
    const [yesterDaysInAppBalance, setYesterDaysInAppBalance] = useState<number>(0);
    const [todaysInAppBalance, setTodaysInAppBalance] = useState<number>(0);
    const [totalExpenses, setTotalExpenses] = useState<number>(0);
    const [expenses, setExpenses] = useState<Expense[]>([
      { id: '1', expense: 'Battery Swap', amount: '', checked: false },
      { id: '2', expense: 'Lunch', amount: '', checked: false },
      { id: '3', expense: 'Police', amount: '', checked: false },
      { id: '4', expense: 'Other', amount: '', checked: false },
    ]);
    const [otherExpenseDescription, setOtherExpenseDescription] = useState<string>("");
    const [clockOutAvailable, setClockOutAvailable] = useState<boolean>(false);
    
    const [loadingAction, setLoadingAction] = useState<string>("Preparing");
    const [refreshing, setRefreshing] = useState<boolean>(false);
    const [showClockOutConfirmationModal, setShowClockOutConfirmationModal] = useState<boolean>(false);
    const [dateString, setDateString] = useState<string>("");
    const [check, setCheck] = useState<boolean>(true);
    const [checkedExpensesWithInputs, setCheckedExpensesWithInputs] = useState([]);
    const [dailyTarget, setDailyTarget] = useState<number>(0);

    const [checkedItems, setCheckedItems] = useState<{ [key: number]: boolean }>({
      1: false,
      2: false,
      3: false,
      4: false,
    });
    const [batterySwapExpense, setBatterySwapExpense] = useState<number>(0);
    const [lunchExpense, setLunchExpense] = useState<number>(0);
    const [policeExpense, setPoliceExpense] = useState<number>(0);
    const [otherExpense, setOtherExpense] = useState<number>(0);

    useFocusEffect(
      useCallback(() => {
          fetchCommissionConstant();
          fetchInAppBalance();
          formatDate();
          CheckIfThisUserIsStillLoggedIn();
          checkAndUpdateUnpushedAmount();
          getDeviceInfo();
      }, [])
    );

    useEffect(() => {
      evaluateTotalExpenses();
    }, [checkedItems, expenses]);

    useEffect( () => {
      calculateNetIncome();
    }, []);

    const evaluateTotalExpenses = () => {
      let total = 0;
      expenses.forEach((item) => {
        if (checkedItems[item.id as unknown as keyof typeof checkedItems] && item.amount !== '') {
          const amount = parseFloat(item.amount);
          if (!isNaN(amount)) {
            total += amount;
          }
        }
      });
      setTotalExpenses(total);
    };

    const formatExpenses = (id: number) => {
      if (id == 1) {
        setBatterySwapExpense(0);
      } else if (id == 2) {
        setLunchExpense(0);
      } else if (id == 3) {
        setPoliceExpense(0);
      } else if (id == 4) {
        setOtherExpense(0);
      }
    }
    const formatExpensesEntries = (id: number, val: string) => {
      // console.log("text changed");
      if (id == 1) {
        setBatterySwapExpense(parseInt(val));
      } else if (id == 2) {
        setLunchExpense(parseInt(val));
      } else if (id == 3) {
        setPoliceExpense(parseInt(val));
      } else {
        setOtherExpense(parseInt(val));
      }
      
    }












    const updateExpense = (id: string, value: string) => {
      setExpenses((prevExpenses) => {
        const updatedExpenses = prevExpenses.map((item) =>
          item.id === id ? { ...item, amount: value } : item
        );
        calculateTotal(updatedExpenses);
        return updatedExpenses;
      });
    };


    const calculateTotal = (expenses: any) => {
      const total = expenses
          .filter((item: any) => item.checked) // Filter checked rows
          .reduce((sum: number, item: any) => sum + parseFloat(item.amount || 0), 0); // Sum amounts
      setTotalExpenses(total);
  };






























    type Expense = {
      id: string;
      expense: string;
      amount: string;
      checked: boolean;
    };

    const fetchCommissionConstant = async () => {
      try {
          if (loadingAction === "Preparing") {
              setLoading(true);
          } else {
              setLoading(false);
          }
          setLoading(true);
          const constantsCollection = collection(db, 'constants');

          // Get all documents in the 'constants' collection
          const querySnapshot = await getDocs(constantsCollection);
  
          if (!querySnapshot.empty) {
          // Assuming you want the first document found
          const firstDoc = querySnapshot.docs[0]; // You can modify this to find a specific document if needed
          const commissionRef = doc(db, 'constants', firstDoc.id);
          const commissionDoc = await getDoc(commissionRef);
  
          if (commissionDoc.exists()) {
              const data = commissionDoc.data();
              setCommissionConstant(data.commission_percentage);
              // console.log(data.commission_percentage);
          } else {
              console.log('No commission constant found');
          }
          } else {
          console.log('No documents in the constants collection');
          }
      } catch (error) {
          console.error('Error fetching commission constant:', error);
      } finally {
          setLoading(false);
      }
    };

    const fetchInAppBalance = async () => {
        try {
            if (loadingAction === "Preparing") {
                setLoading(true);
            } else {
                setLoading(false);
            }
            const usersCollection = collection(db, 'users');

            // Get all documents in the 'constants' collection
            const querySnapshot = await getDocs(usersCollection);
    
            if (!querySnapshot.empty) {
              if (auth.currentUser) {
                const inAppBalRef = doc(db, "users", auth.currentUser.uid);
                const inAppBalDoc = await getDoc(inAppBalRef);
        
                if (inAppBalDoc.exists()) {
                    const data = inAppBalDoc.data();
                    setYesterDaysInAppBalance(data.current_in_app_balance || 0);
                    setDailyTarget(data.daily_target);
                } else {
                    console.log('No commission constant found');
                }
              } else {
                console.error("User is not logged in");
              }
            } else {
            console.log('No documents in the constants collection');
            }
        } catch (error) {
            console.error('Error fetching commission constant:', error);
        } finally {
            setLoading(false);
        }
    };

    const getMonth = (digit: number) => {
      const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      return months[digit];
    }

   

    useEffect(() => {
        calculateNetIncome();
    }, [grossIncome, commissionConstant, totalExpenses, yesterDaysInAppBalance, todaysInAppBalance, check]);

    const calculateNetIncome = () => {
      
        const gross : number = grossIncome || 0;
        const commission = commissionConstant || 0;
        // Formula: gross * (100 - commissionConstant) / 100 - totalExpenses
        const net = gross * (1 - commission / 100) - (todaysInAppBalance ? todaysInAppBalance - yesterDaysInAppBalance : 0 - yesterDaysInAppBalance) - totalExpenses;
        setNetIncome(parseFloat(net.toFixed(2)));
    };
    
    const formatCurrency = (amount: number) => {
        return new Intl.NumberFormat('en-KE', {
          style: 'currency',
          currency: 'KES',
          minimumFractionDigits: 0
        }).format(amount);
    };

    const EvalMonth = (digit : number) => {
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return months[digit];
    }

    const formatDate = () => {
        const date = new Date();
        const day = date.getDate().toString().padStart(2, '0'); // Ensure two-digit day
        const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const month = monthNames[date.getMonth()]; // Get short month name
        const year = date.getFullYear();
      
        setDateString(`${day}-${month}-${year}`);

        checkIfClockOutAlreadyExists(`${day}-${month}-${year}`);
    };


    const checkIfClockOutAlreadyExists = async (string_for_date: any) => {
      
      if (!auth.currentUser) {
        console.log("No authenticated user.");
        return;
      }
    
      console.log(string_for_date);
      const userUid = auth.currentUser.uid;
      const clockOutDocRef = doc(db, "users", userUid, "clock_outs", string_for_date);
    
      try {
        const docSnap = await getDoc(clockOutDocRef);
        
        if (docSnap.exists()) {
          setClockOutAvailable(true); // If the document exists, set state to true
          console.log("Clock-out record exists for", string_for_date);
        } else {
          setClockOutAvailable(false); // Otherwise, set state to false
          console.log("No clock-out record found for", string_for_date);
        }
      } catch (error) {
        console.error("Error checking clock-out record:", error);
      }
    };

    async function getDeviceInfo() {
      setDeviceInfo(`${Device.deviceName}, ${Device.osName} ${Device.osVersion}`);
    }

    

    const toggleCheck = (id: number) => {
      setCheckedItems((prev) => ({
        ...prev,
        [id]: !prev[id], // Toggle the checkbox state
      }));

      setExpenses((prevExpenses) =>
        prevExpenses.map((item) =>
          item.id === id ? { ...item, checked: !item.checked, amount: item.checked ? "0" : item.amount } : item
      // item.id === id ? { ...item, checked: !item.checked, amount: item.checked ? "0" : item.amount } : item
    )
      );
    };

    // const toggleCheck = (id: string) => {
    //   setExpenses((prevExpenses) =>
    //     prevExpenses.map((item) =>
    //       item.id === id ? { ...item, checked: !item.checked, amount: item.checked ? "0" : item.amount } : item
    //     )
    //   );
    // };
    
    

    const LogOut = async () => {
      await signOut(auth);
    }

    const ClockOut = () => {
      if (otherExpense > 0 && !(otherExpenseDescription.length > 3)){
        Alert.alert('Action stopped', "Your 'Other' expense is not well described.")
        return;
      }
      setShowClockOutConfirmationModal(true);

    }

    const FinishDay = async () => {
      setShowClockOutConfirmationModal(false); //
      setPosting(true);
      if (!auth.currentUser) {
        console.error("No authenticated user found.");
        return;
      }

      const dataToPost = {
        gross: grossIncome,
        in_app_balance: todaysInAppBalance ? todaysInAppBalance : 0,
        net: netIncome,
        expenses: {
          battery_swap: batterySwapExpense,
          lunch: lunchExpense,
          police: policeExpense,
          other: {
            name: otherExpense > 0 ? otherExpenseDescription : "",
            amount: otherExpense ? otherExpense : 0,
          }
        }
      }
      const userId = auth.currentUser.uid;

      // await set
      try {
        const clockOutRef = doc(db, "users", userId, "clock_outs", dateString);
        await setDoc(clockOutRef, dataToPost, { merge: false });
        console.log("Clock-out data successfully posted!");



        // Reference to the user's document
        const userRef = doc(db, "users", userId);
        const monthInt = new Date().getMonth();
        const currentMonth = EvalMonth(monthInt);
        const nextMonth = EvalMonth(monthInt + 1);

        const decrement = (value: number) => increment(-value);
    
        // Update Firestore fields in one request
        await updateDoc(userRef, {
          current_in_app_balance: todaysInAppBalance,  // Set today's balance
          amount_pending_approval: increment(Math.ceil(netIncome)), // Increment amount pending approval
          unpushed_amount: decrement(Math.ceil(netIncome)), // Increment amount pending approval
          last_clock: dateString,
          net_clocked: Math.ceil(netIncome),
          filterable_date: new Date().toISOString(),
          device_info: deviceInfo,
          // device: `${DeviceInfo.getBrand()} ${DeviceInfo.getModel()} ${DeviceInfo.getSystemName()} ${DeviceInfo.getSystemVersion()}`,
          // device_id: DeviceInfo.getUniqueId(),
          [`net_incomes.${currentMonth}`]: increment(Math.ceil(netIncome)),
          [`net_incomes.${nextMonth}`]: 0,
          [`deviation_from_target.${currentMonth}`]: increment(Math.ceil(netIncome) - dailyTarget),
          [`deviation_from_target.${nextMonth}`]: 0,
        });
    
        console.log("Financial data 2 updated successfully!");

      } catch (error) {
        console.error("Error posting clock-out data:", error);
      } finally {
        setPosting(false);
        setClockOutAvailable(true); //
        setGrossIncome(0);
        setTodaysInAppBalance(0);
        Alert.alert("Success", "Clock-out data successfully posted!");
      }
    }
  
  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
      <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
        <View style={styles.innerContainer}>
          <View style={styles.evenInnerContainer1}>
              <Text style={styles.regText1}>Fill all necessary fields. <Text style={styles.dateText}>{dateString}</Text> </Text>
              {/* gross */}
              <View style={styles.universalView}>
                  {/* <Ionicons name="bar-chart" style={styles.icons} size={28} color="green" /> */}
                  <Text style={styles.regText2}>Gross App Income</Text>
                  <TextInput
                    value={grossIncome !== null ? grossIncome.toString() : ""}
                    onChangeText={(text) => {
                      if (text === "") {
                        setGrossIncome(null); // Allow clearing the input
                        return;
                      }
                      
                      const numericValue = parseFloat(text.replace("%", ""));
                      if (!isNaN(numericValue)) {
                        setGrossIncome(numericValue);
                      }
                    }}
                    style={styles.inputType1}
                    autoCapitalize="none"
                    keyboardType="numeric"
                  />
              </View>

              {/* commission 100% - c% = s_g */}
              <View style={styles.universalView}>
                  {/* <Ionicons name="bar-chart" style={styles.icons} size={28} color="green" /> */}
                  <Text style={styles.regText2}>Commission Constant</Text>
                  <TextInput
                      value={commissionConstant ? commissionConstant.toString() + "%" : ''}
                      onChangeText={(text) => {
                        const numericValue = parseFloat(text);
                        if (!isNaN(numericValue)) {
                          setCommissionConstant(numericValue);
                        }
                      }}
                      style={styles.inputType2}
                      autoCapitalize="none"
                      keyboardType="numeric"
                      editable={false}
                  />
              </View>

              {/* last seen in-app balance */}
              <View style={styles.universalView}>
                  <Text style={styles.regText2}>Previous In-App Balance</Text>
                  <TextInput
                      value={yesterDaysInAppBalance ? formatCurrency(Math.ceil(yesterDaysInAppBalance)) + ".00" : ''}
                      onChangeText={(text) => {
                        const numericValue = parseFloat(text);
                        if (!isNaN(numericValue)) {
                          setYesterDaysInAppBalance(numericValue);
                        }
                      }}
                      style={styles.inputType2}
                      autoCapitalize="none"
                      keyboardType="numeric"
                      editable={false}
                  />
              </View>

              {/* todays in-app (request) */}
              <View style={styles.universalView}>
                  <Text style={styles.regText2}>Today's In-App Balance</Text>
                  <TextInput
                    value={todaysInAppBalance !== null ? todaysInAppBalance.toString() : ""}
                    onChangeText={(text) => {
                      if (text === "") {
                        setTodaysInAppBalance(0); // Allow clearing the input
                        return;
                      }

                      const numericValue = parseFloat(text.replace("%", ""));
                      if (!isNaN(numericValue)) {
                        setTodaysInAppBalance(numericValue);
                      }
                    }}
                    style={styles.inputType1}
                    autoCapitalize="none"
                    keyboardType="numeric"
                    editable={true}
                  />

              </View>

              <View style={styles.universalView}>
                  <Text style={styles.regText2}>Expenses</Text>
              </View>

              {/* <ExpensesTable /> */}
              <View style={{ padding: 20 }}>
              <View style={{ borderWidth: 1, borderColor: "#ccc", borderRadius: 10, padding: 10, marginBottom: 0 }}>
                {expenses.map((item: any) => (
                  <View key={item.id} style={{ flexDirection: "column", marginBottom: 10 }}>

                    {/* Expense CheckBox and Amount Input */}
                    <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
                      <CheckBox
                        selected={checkedItems[item.id]}
                        onPress={() => {
                          toggleCheck(item.id);
                          checkedItems[item.id] && formatExpenses(item.id);
                          // checkedItems[item.id] && item.amount = 0;
                        }}
                        text={`${item.expense}`}
                      />
                      <TextInput
                        value={item.amount}
                        // value={expenseList[item.id]?.toString() || ""}
                        // value={checkedItems[item.id] ? item.amount : 0}
                        onChangeText={(value) => {
                          updateExpense(item.id, value);
                          formatExpensesEntries(item.id, value);
                        }}
                        style={[
                          styles.input,
                          checkedItems[item.id]
                            ? { borderColor: "rgba(0, 128, 0, 0.175)", borderWidth: 2, backgroundColor: "#fff", width: 100, borderRadius: 10 }
                            : { borderColor: "gray", borderWidth: 2, backgroundColor: "transparent", width: 100, borderRadius: 10 },
                        ]}
                        keyboardType="numeric"
                        editable={checkedItems[item.id]}
                        placeholder="0.00"
                      />
                    </View>

                    {/* Show Description Input when 'Other' is checked */}
                    {item.expense === "Other" && checkedItems[item.id] && (
                      <TextInput
                        // value={item.description || ""}
                        value={otherExpenseDescription}
                        onChangeText={setOtherExpenseDescription}
                        style={{
                          borderWidth: 1,
                          borderColor: "#ccc",
                          borderRadius: 10,
                          padding: 20,
                          marginTop: 5,
                          backgroundColor: "#fff",
                          color: "gray",
                          fontSize: 16,
                        }}
                        placeholder="Describe the expense..."
                        maxLength={100} // Restrict input to 100 characters
                      />
                    )}
                  </View>
                ))}
              </View>

              </View>

              {/* warn */}
              <View style={styles.universalView}>
                  <Text style={styles.regText3}>Unchecked expenses are void.</Text>
              </View>

              {/* net */}
              <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginTop: 10, marginBottom: 20 }}>
                  <View style={{ position: 'relative' }}>
                      <Text style={[styles.regText4, { textDecorationLine: 'underline' }]}>{formatCurrency(Math.ceil(netIncome))}.00</Text>
                      <View
                      style={{
                          height: 1,
                          backgroundColor: 'green', // Color of the second underline
                          position: 'absolute',
                          bottom: -.25,
                          left: 0,
                          right: 0,
                      }}
                      />
                  </View>
              </View>

              {/* <MyButton title="Push this amount for approval" bgColor='green' onPress={finalizeEndDayReport} /> */}
              <View style={{ flexDirection: 'row', justifyContent: 'space-around', marginTop: 10, backgroundColor: "rgba(0, 128, 0, 0.075)", marginBottom: 20, borderRadius: 20, padding: 10 }}>
                <Button1 title={  `Log Out` } bgColor='rgba(255, 165, 0, 0.775)' onPress={LogOut} />
                <Button1 title={  `Clock Out`  } bgColor='green' onPress={ClockOut} />
              </View>




          </View>




          <Modal
              visible={showClockOutConfirmationModal}
              transparent={true}
              animationType="fade"
              onRequestClose={() => setShowClockOutConfirmationModal(false)}
          >
              <View style={styles.modalContainer}>
                  <View style={styles.modalContent}>
                      {!clockOutAvailable &&
                        <Text style={styles.modalTitle}>Confirm Clock-Out for date <Text style={styles.modalImp}>{dateString}</Text> with an amount of <Text style={styles.modalImp}>{formatCurrency(Math.ceil(netIncome))}.00</Text>.</Text>
                      }
                      
                      {clockOutAvailable && 
                        <View style={{ backgroundColor: 'rgba(128, 0, 0, 0.175)', padding: 20, borderRadius: 20}}>
                            <Text style={styles.modalTitle2}>There already exists a record showing that you have clocked out today.</Text>
                            <Button1  title={`Exit`} bgColor='rgba(255, 0, 0, 0.775)' onPress={() => setShowClockOutConfirmationModal(false)}/>

                        </View>

                      }

                      {!clockOutAvailable && <View style={{ flexDirection: 'row', justifyContent: 'space-around', marginTop: 10, backgroundColor: "rgba(0, 128, 0, 0.075)", marginBottom: 20, borderRadius: 20, }}>
                          <Button1  title={`Cancel`} bgColor='rgba(255, 165, 0, 0.775)' onPress={() => setShowClockOutConfirmationModal(false)}/>
                          <Button1  title={`Confirm`} bgColor='green' onPress={FinishDay}/>
                      </View>}
                  </View>
              </View>
          </Modal>





          {/* Loading Modal */}
          <Modal transparent={true} visible={loading}>
              <View style={styles.modalContainer}>
              <ActivityIndicator size="large" color="green" />
              <Text style={styles.loadingText}>{loadingAction} template...</Text>
              </View>
          </Modal>
          {/* posting Modal */}
          <Modal transparent={true} visible={posting}>
              <View style={styles.modalContainer}>
              <ActivityIndicator size="large" color="green" />
              <Text style={styles.loadingText}>Submitting report...</Text>
              </View>
          </Modal>
      </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  keyboardView: {
      flex: 1,
    },
    scrollContainer: {
        padding: 0,
    },
    innerContainer: {
        flex: 1,
        justifyContent: 'center',
    },

    universalView: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginTop: 20},

    evenInnerContainer1: {
      borderRadius: 10,
      // iOS Shadow
      shadowColor: 'rgb(200, 200, 200)',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.2,
      shadowRadius: 5,
      // Android Shadow
      elevation: 0, // Adds shadow on Android
      padding: 20,
      margin: 10,
      backgroundColor: "rgba(0, 128, 0, 0.075)",
    },

    icons: {

    },
    regText1: {
      // color: "rgba(0, 128, 0, 0.375)",
      color: "green",
      fontSize: 20,
      textAlign: 'left',
      fontWeight: 'bold',
      padding: 0,
    },
    regText2: {
      color: "gray",
      fontSize: 15,
      textAlign: 'left',
      fontWeight: 'bold',
      padding: 0,
    },
    regText3: {
      color: "rgba(200, 0, 0, 0.375)",
      fontSize: 18,
      textAlign: 'left',
      fontWeight: 'bold',
      padding: 0,
    },
    regText4: {
      color: "green",
      fontSize: 30,
      textAlign: 'left',
      fontWeight: 'bold',
      padding: 0,
    },
    dateText: {
      color: "red",
      fontFamily: "monospace",
      textDecorationLine: "underline", 
    },
    inputType1: {
      height: 50,
      borderColor: 'rgba(0, 128, 0, 0.175)',
      borderWidth: 2,
      marginBottom: 0,
      paddingHorizontal: 8,
      borderRadius: 10,
      backgroundColor: '#fff',
      marginTop: 0,
      marginLeft: 20,
      width: "40%",
    },
    inputType2: {
      height: 50,
      borderWidth: .5,
      marginBottom: 0,
      paddingHorizontal: 8,
      borderRadius: 10,
      backgroundColor: 'rgb(230, 230, 230)',
      borderColor: "gray",
      marginTop: 0,
      marginLeft: 20,
      width: "40%",
      textAlign: "center",
    },
    input: {
      height: 50,
      borderColor: 'rgba(0, 128, 0, 0.175)',
      borderWidth: 1,
      marginBottom: 0,
      paddingHorizontal: 8,
      borderRadius: 10,
      backgroundColor: '#fff',
      marginTop: 0,
    },
    alignContainer1: {
      display: 'flex',
      flexDirection: 'row',
      justifyContent: 'flex-end',
      paddingRight: 10,
  },
    modalContent: {
      width: '80%',
      padding: 20,
      backgroundColor: 'white',
      borderRadius: 30,
  },
  modalTitle: {
      textAlign: 'center',
      fontSize: 18,
      fontWeight: 'thin',
      marginBottom: 15,
  },
  modalTitle2: {
      textAlign: 'center',
      fontSize: 18,
      fontWeight: 'thin',
      marginBottom: 15,
      color: 'red',
      fontFamily: "monospace",
  },
  modalImp: {
    fontWeight: 'bold',
    color: 'rgba(255, 165, 0, 0.775)',
  },










    modalContainer: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      backgroundColor: 'rgba(0, 0, 0, 0.8)',
    },
    loadingText: {
      marginTop: 10,
      fontSize: 16,
      color: '#fff',
    },
});
