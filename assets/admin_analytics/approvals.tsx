import { useFocusEffect } from "expo-router";
import { collection, doc, getDocs, increment, query, updateDoc, where, writeBatch } from "firebase/firestore";
import { useCallback, useState } from "react";
import { KeyboardAvoidingView, Text, View, StatusBar, ScrollView, StyleSheet, Platform, Modal, ActivityIndicator, RefreshControl, TextInput, Alert, UIManager, LayoutAnimation, TouchableOpacity, Linking } from "react-native";
import db from "../utilities/firebase_file";
import Button1 from "../utilities/button1";
import checkAndUpdateUnpushedAmount from "../utilities/check_increment_dates";
// import { ChevronDown, ChevronUp } from 'lucide-react-native';
import { AntDesign, Ionicons } from '@expo/vector-icons';

export default function Approvals() {
    const [users, setUsers] = useState<any>([]);
    const [loading, setLoading] = useState<boolean>(false);
    const [updatingData, setUpdatingData] = useState<boolean>(false);
    const [refreshing, setRefreshing] = useState<boolean>(false);
    const [showPartialApprovalModal, setShowPartialApprovalModal] = useState<boolean>(false);
    const [showFormattingModal, setShowFormattingModal] = useState<boolean>(false);
    const [showTargetModal, setShowTargetModal] = useState<boolean>(false);
    const [showInAppModal, setShowInAppModal] = useState<boolean>(false);
    const [showAllUserResetModal, setShowAllUserResetModal] = useState<boolean>(false);
    const [month, setMonth] = useState<string>("");
    const [longMonth, setLongMonth] = useState<string>("");
    

    const [username, setUsername] = useState<string>("");
    const [partialApprovalAmount, setPartialApprovalAmount] = useState<string>("");
    const [alterTargetAmount, setAlterTargetAmount] = useState<string>("");
    const [maximumApprovalAmount, setMaximumApprovalAmount] = useState<string>("");
    const [newInAppBal, setNewInAppBal] = useState<string>("");

    useFocusEffect(
        useCallback( () => {
            fetchUsers();
            currentMonth();
            checkAndUpdateUnpushedAmount();
            getMonth();
        }, [])
    )

    // Enable LayoutAnimation on Android
    if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
        UIManager.setLayoutAnimationEnabledExperimental(true);
    }
    
    const [expandedUsers, setExpandedUsers] = useState<string[]>([]);
    
    const toggleExpand = (username: string) => {
        LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
        if (expandedUsers.includes(username)) {
        setExpandedUsers(expandedUsers.filter(name => name !== username));
        } else {
        setExpandedUsers([...expandedUsers, username]);
        }
    };

    const onRefresh = async () => {
        setRefreshing(true);
        try {
            await Promise.all([fetchUsers(),]);
        } catch (error) {
            console.error("Error refreshing data:", error);
        } finally {
            setRefreshing(false); // Ensures it stops refreshing after function is done
        }
    };

    const fetchUsers = async () => {
        try {
            if (!refreshing) {
                setLoading(true);
            }
            const usersCollection = collection(db, "users"); // Reference to users collection
            const querySnapshot = await getDocs(usersCollection);
            
            // Map through documents and extract user data
            const usersList = querySnapshot.docs.map((doc) => ({
                id: doc.id, // UID
                ...doc.data(), // Other user data
            }));

            const sortedUsers = usersList
            .filter((user: any) => user.role !== "CEO" && !user.is_deleted)
            .sort((a: any, b: any) => {
                const dateA = a.filterable_date ? new Date(a.filterable_date).getTime() : 0;
                const dateB = b.filterable_date ? new Date(b.filterable_date).getTime() : 0;

                // If both have dates, sort by date
                if (dateA && dateB) return dateB - dateA;

                // If only one has a date, push the one without to the bottom
                if (dateA && !dateB) return -1;  // a comes before b
                if (!dateA && dateB) return 1;   // b comes before a

                // If neither has a date, keep original order (or you can return 0)
                return 0;
            });

    
            setUsers(sortedUsers); // Update state with users
        } catch (error) {
            console.error("Error fetching users:", error);
        } finally {
            setLoading(false);
            
        }
    };

    const formatCurrency = (amount: number) => {
        return new Intl.NumberFormat('en-KE', {
          style: 'currency',
          currency: 'KES',
          minimumFractionDigits: 0
        }).format(amount);
    };
    
    const currentMonth = () => {
        const month = new Date().getMonth();
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        setMonth(months[month]);
    }

    const getMonth = () => {
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        const month = new Date().getMonth();
        setLongMonth(months[month]);
    }
  
    const approveAll = async () => {
        try {
            setUpdatingData(true);
            if (!username) {
              Alert.alert("Error", "We couldn't find a valid username.")
              return;
            }
            
            // Query Firestore to find the user by username
            const usersRef = collection(db, "users");
            const q = query(usersRef, where("username", "==", username));
            const querySnapshot = await getDocs(q);
            
            if (querySnapshot.empty) {
                console.log("User not found.");
                return;
            }
            
            // There should be only one matching user, but we loop in case of duplicates
            querySnapshot.forEach(async (userDoc) => {
                const userRef = doc(db, "users", userDoc.id);
                await updateDoc(userRef, { amount_pending_approval: 0 });
                Alert.alert("Success", `Complete approval for ${username} completed.`);
            });
            
        } catch (error: any) {
            console.error("Error approving all:", error);
            Alert.alert("Failed", `Approval failed: ${error.message}`);
        } finally {
            setUpdatingData(false);
            setShowFormattingModal(false);

            fetchUsers();
            currentMonth();
        }
    }
    const approvePartial = async () => {
        if (parseInt(partialApprovalAmount) > parseInt(maximumApprovalAmount)) {
            Alert.alert("Stop!", "You can only approve upto the limit stated.");
            return;
        }
        try {
            setUpdatingData(true);
            if (!username) {
              console.log("No username provided.");
              return;
            }
            if (!partialApprovalAmount || parseInt(partialApprovalAmount) <= 0) {
              Alert.alert("Error", "The amount you entered could not be ascertained as valid.")
              return;
            }
        
            // Query Firestore to find the user by username
            const usersRef = collection(db, "users");
            const q = query(usersRef, where("username", "==", username));
            const querySnapshot = await getDocs(q);
        
            if (querySnapshot.empty) {
              console.log("User not found.");
              return;
            }
        
            // Loop through users (in case of duplicates) and decrement the approval amount
            querySnapshot.forEach(async (userDoc) => {
              const userRef = doc(db, "users", userDoc.id);
              await updateDoc(userRef, { amount_pending_approval: increment(-Math.abs(parseInt(partialApprovalAmount))) });
              console.log(`Approved ${formatCurrency(parseInt(partialApprovalAmount))}.00 for ${username}`);
            });
        
          } catch (error) {
            console.error("Error approving partial amount:", error);
          } finally {
            setUpdatingData(false);
            setShowPartialApprovalModal(false);
            setPartialApprovalAmount("0");

            fetchUsers();
            currentMonth();
          }
    }
    const alterTarget = async() => {
        try {
            setUpdatingData(true);
            if (!username) {
              Alert.alert("Error", "We couldn't find a valid username.")
              return;
            }
            
            // Query Firestore to find the user by username
            const usersRef = collection(db, "users");
            const q = query(usersRef, where("username", "==", username));
            const querySnapshot = await getDocs(q);
            
            if (querySnapshot.empty) {
                console.log("User not found.");
                return;
            }
            
            // There should be only one matching user, but we loop in case of duplicates
            querySnapshot.forEach(async (userDoc) => {
                const userRef = doc(db, "users", userDoc.id);
                await updateDoc(userRef, { daily_target: alterTargetAmount });
                Alert.alert("Success", `Target amount altered for ${username}.`);
            });
            
        } catch (error: any) {
            console.error("Error approving all:", error);
            Alert.alert("Failed", `Target alteration failed: ${error.message}`);
        } finally {
            setUpdatingData(false);
            setShowTargetModal(false);
            setAlterTargetAmount("0");

            fetchUsers();
            currentMonth();
        }
    }

    const ChangeInAppBal = async() => {
        try {
            setUpdatingData(true);
            if (!username) {
              Alert.alert("Error", "We couldn't find a valid username.")
              return;
            }
            
            // Query Firestore to find the user by username
            const usersRef = collection(db, "users");
            const q = query(usersRef, where("username", "==", username));
            const querySnapshot = await getDocs(q);
            
            if (querySnapshot.empty) {
                console.log("User not found.");
                return;
            }
            
            // There should be only one matching user, but we loop in case of duplicates
            querySnapshot.forEach(async (userDoc) => {
                const userRef = doc(db, "users", userDoc.id);
                await updateDoc(userRef, { current_in_app_balance: newInAppBal });
                Alert.alert("Success", `${username}'s In-App balance changed.`);
            });
            
        } catch (error: any) {
            console.error("Error approving all:", error);
            Alert.alert("Failed", `In-App balance alteration failed: ${error.message}`);
        } finally {
            setUpdatingData(false);
            setShowInAppModal(false);
            setNewInAppBal("0");

            fetchUsers();
            currentMonth();
        }
    }

    const resetAllUsersPendings = async () => {
        try {
            setShowAllUserResetModal(false); //
            setUpdatingData(true);
            const usersRef = collection(db, 'users');
            const snapshot = await getDocs(usersRef);
        
            const batch = writeBatch(db);
        
            snapshot.forEach((doc) => {
                const userRef = doc.ref;
                batch.update(userRef, { amount_pending_approval: 0 });
            });
        
            await batch.commit();
            Alert.alert('Success', 'All user pending amounts have been reset.');
        } catch (error: any) {
          Alert.alert('Error resetting user pendings:', error.message);
        } finally {
            setShowAllUserResetModal(false);
            setUpdatingData(false);

            fetchUsers();
            currentMonth();
        }
      };

    const makePhoneCall = (phone: string) => {
        
        Linking.openURL(`tel:${phone.length == 9 ? "0" : ""}${phone}`);
    };
    const sendSMS = (phone: string) => {
        if (!phone) return Alert.alert("Invalid phone number");
        const message = "From: BILLK MOTOLINK LTD\n"
        let url = `sms:${phone}`;
        if (message) {
          url += `?body=${encodeURIComponent(message)}`;
        }
        Linking.openURL(url);
      };
    const openWhatsApp = (phone: string) => {
        const countryCode = "254"; // Example: "1" for USA, "254" for Kenya
        
        const url = `whatsapp://send?phone=${countryCode}${phone}&text=From: BILLK MOTOLINK LTD\n`;
        
        Linking.openURL(url).catch(() => {
            Alert.alert('Error', 'Make sure WhatsApp is installed on your device');
        });
    };

      
    return (
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}
        >
            <StatusBar
                barStyle="light-content"
                backgroundColor="green"
                />
            <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled"
                refreshControl={
                    <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={["green"]} />
                }
            >
                {
                    users.map( (user: any, key: number) => (
                        // user.role !== "CEO" && !user.is_deleted &&
                        // <View style={user.is_active ? styles.container1 : styles.container11} key={key}>
                        //     <Text style={styles.username}>{user.username} <Text style={styles.activeStatus}>{user.is_active ? "(active)" : "(inactive)"} -- {user.role}</Text></Text>
                        //     <Text style={styles.regText}>Amount Pending Approval: <Text style={styles.amounts2}>{formatCurrency(parseInt(user.amount_pending_approval))}.00</Text></Text>
                        //     <Text style={styles.regText}>Daily Target: <Text style={styles.amounts}>{formatCurrency(parseInt(user.daily_target))}.00</Text></Text>
                        //     <Text style={styles.regText}>Last Clock Date: <Text style={styles.amounts}>{user.last_clock ? user.last_clock : "Null"}</Text></Text>
                        //     <Text style={styles.regText}>Net Clocked: <Text style={styles.amounts}>{user.net_clocked ? formatCurrency(parseInt(user.net_clocked)) : 0}.00</Text></Text>
                        //     <Text style={styles.regText}>Device Clocked: <Text style={styles.amounts}>{user.device_info  ?? "Unknown" }</Text></Text>
                        //     <Text style={styles.regText}>Unpushed Income: <Text style={styles.amounts}>{formatCurrency(parseInt(user.unpushed_amount))}.00</Text></Text>
                        //     <Text style={styles.regText}>Performance: <Text style={styles.amounts}>{user.deviation_from_target  ? Math.abs((parseInt(user.deviation_from_target[month]) / user.daily_target) * 100).toFixed(2)  : 100}%</Text></Text>
                        //     <Text style={styles.regText}>{longMonth} Net: <Text style={styles.amounts}>{ user.net_incomes?.[month] ? formatCurrency(parseInt(user.net_incomes[month])) : formatCurrency(0)}.00</Text></Text>

                        //     <View style={{ flexDirection: 'column', justifyContent: 'space-around', marginTop: 10, backgroundColor: `${user.is_active ? 'rgba(0, 128, 0, 0.075)' : 'rgba(158, 0, 0, 0.075)'}`, marginBottom: 0, borderRadius: 20, padding: 20 }}>
                        //         <Button1  title={`Approve a Partial Amount`} bgColor='rgba(255, 165, 0, 0.775)'
                        //         onPress={() => {
                        //             setShowPartialApprovalModal(true);
                        //             setUsername(user.username);
                        //             setMaximumApprovalAmount(user.amount_pending_approval)
                        //         }}/>
                        //         <Button1  title={`Reset Pending Amount`} bgColor='red' onPress={() => {
                        //             setShowFormattingModal(true); //
                        //             setUsername(user.username);
                        //         }}/>
                        //         <Button1  title={`Change Target`} bgColor='green' onPress={() => {
                        //             setShowTargetModal(true);
                        //             setUsername(user.username);
                        //         }}/>
                        //     </View>
                        // </View>

                        <View
                            style={user.is_active ? styles.container1 : styles.container11}
                            key={key}
                            >
                            <TouchableOpacity
                                onPress={() => toggleExpand(user.username)}
                                style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}
                            >
                                <Text style={styles.username}>
                                {user.username}
                                <Text style={styles.activeStatus}>
                                    {user.is_active ? " (Active)" : " (Inactive)"} -- {user.role}
                                </Text>
                                </Text>
                            </TouchableOpacity>

                            {expandedUsers.includes(user.username) && (
                                <View>
                                    <Text style={styles.regText}>Amount Pending Approval: <Text style={styles.amounts2}>{formatCurrency(parseInt(user.amount_pending_approval))}.00</Text></Text>
                                    <Text style={styles.regText}>Current In-App Balance: <Text style={styles.amounts2}>{formatCurrency(parseInt(user.current_in_app_balance))}.00</Text></Text>
                                    <Text style={styles.regText}>Daily Target: <Text style={styles.amounts}>{formatCurrency(parseInt(user.daily_target))}.00</Text></Text>
                                    <Text style={styles.regText}>Last Clock Date: <Text style={styles.amounts}>{user.last_clock || "Null"}</Text></Text>
                                    <Text style={styles.regText}>Net Clocked: <Text style={styles.amounts}>{user.net_clocked ? formatCurrency(parseInt(user.net_clocked)) : 0}.00</Text></Text>
                                    <Text style={styles.regText}>Device Clocked From: <Text style={styles.amounts}>{user.device_info ?? "Unknown"}</Text></Text>
                                    <Text style={styles.regText}>Unpushed Income: <Text style={styles.amounts}>{formatCurrency(parseInt(user.unpushed_amount))}.00</Text></Text>
                                    <Text style={styles.regText}>Performance: <Text style={styles.amounts}>{user.deviation_from_target ? Math.abs((parseInt(user.deviation_from_target[month]) / user.daily_target) * 100).toFixed(2) : 100}%</Text></Text>
                                    <Text style={styles.regText}>{longMonth} Net: <Text style={styles.amounts}>{user.net_incomes?.[month] ? formatCurrency(parseInt(user.net_incomes[month])) : formatCurrency(0)}.00</Text></Text>
                                    <View
                                        style={{
                                        flexDirection: 'row',
                                        justifyContent: 'space-between',
                                        marginTop: 10,
                                        backgroundColor: user.is_active ? 'rgba(0, 128, 0, 0.075)' : 'rgba(158, 0, 0, 0.075)',
                                        marginBottom: 0,
                                        borderRadius: 20,
                                        padding: 20,
                                        }}
                                    >
                                        <TouchableOpacity
                                            onPress={() => makePhoneCall(user.phone_number)}>
                                            <View style={{ flexDirection: 'column', alignItems: 'center' }}>
                                                <Ionicons name="call" size={28} color={'red'} />
                                                <Text style={{ fontWeight: 'bold', color: 'gray' }}>Call Now</Text>
                                            </View>
                                        </TouchableOpacity>

                                        <TouchableOpacity
                                            onPress={() => sendSMS(user.phone_number)}>
                                            <View style={{ flexDirection: 'column', alignItems: 'center' }}>
                                                <Ionicons name="logo-wechat" size={28} color={'orange'} />
                                                <Text style={{ fontWeight: 'bold', color: 'gray' }}>Text</Text>
                                            </View>

                                        </TouchableOpacity>

                                        <TouchableOpacity onPress={() => openWhatsApp(user.phone_number)}>
                                            <View style={{ flexDirection: 'column', alignItems: 'center' }}>
                                                <Ionicons name="logo-whatsapp" size={28} color={'green'} />
                                                <Text style={{ fontWeight: 'bold', color: 'gray' }}>WhatsApp</Text>
                                            </View>
                                        </TouchableOpacity>

                                    </View>

                                    <View
                                        style={{
                                        flexDirection: 'column',
                                        justifyContent: 'space-around',
                                        marginTop: 10,
                                        backgroundColor: user.is_active ? 'rgba(0, 128, 0, 0.075)' : 'rgba(158, 0, 0, 0.075)',
                                        marginBottom: 0,
                                        borderRadius: 20,
                                        padding: 20,
                                        }}
                                    >
                                        <Button1
                                        title={`Approve a Partial Amount`}
                                        bgColor="rgba(255, 165, 0, 0.775)"
                                        onPress={() => {
                                            setShowPartialApprovalModal(true);
                                            setUsername(user.username);
                                            setMaximumApprovalAmount(user.amount_pending_approval);
                                        }}
                                        />
                                        <Button1
                                        title={`Reset Pending Amount`}
                                        bgColor="red"
                                        onPress={() => {
                                            setShowFormattingModal(true);
                                            setUsername(user.username);
                                        }}
                                        />
                                        <Button1
                                        title={`Change Target`}
                                        bgColor="green"
                                        onPress={() => {
                                            setShowTargetModal(true);
                                            setUsername(user.username);
                                        }}
                                        />
                                        <Button1
                                        title={`Change In-App Balance`}
                                        bgColor="blue"
                                        onPress={() => {
                                            setShowInAppModal(true);
                                            setUsername(user.username);
                                        }}
                                        />
                                    </View>
                                </View>
                            )}
                            </View>

                    ))
                }

                <View>
                    <Button1  title={`Approve all pending amounts to 0`} bgColor='red' onPress={() => {setShowAllUserResetModal(true);}}/>               
                </View>

                


                {/* partial approve */}
                <Modal
                    visible={showPartialApprovalModal}
                    transparent={true}
                    animationType="slide"
                    onRequestClose={() => {setShowPartialApprovalModal(false); setPartialApprovalAmount("0"); setMaximumApprovalAmount("0")}}
                >
                    <View style={styles.modalContainer}>
                        <View style={styles.modalContent}>
                            <Text style={styles.modalTitle}>Approve a partial amount for <Text style={styles.username2}>{username}.</Text></Text>
                            <Text style={styles.maxAmount}>(Ksh 0.00 - {formatCurrency(parseInt(maximumApprovalAmount))}.00)</Text>
                            <TextInput
                                placeholder="Amount"
                                value={partialApprovalAmount}
                                onChangeText={setPartialApprovalAmount}
                                style={styles.input}
                                keyboardType="numeric"
                            />
                            
                            <View style={styles.alignContainer1}>
                                <Button1  title={`Cancel`} bgColor='red' onPress={() => {setShowPartialApprovalModal(false); setPartialApprovalAmount("0");}}/>
                                <Button1  title={`Approve amount`} bgColor='rgba(0, 128, 0, 0.775)' onPress={approvePartial}/>
                            </View>
                        </View>
                    </View>
                </Modal>
                
                {/* formatting */}
                <Modal
                    visible={showFormattingModal}
                    transparent={true}
                    animationType="slide"
                    onRequestClose={() => setShowFormattingModal(false)}
                >
                    <View style={styles.modalContainer}>
                        <View style={styles.modalContent}>
                            <Text style={styles.modalTitle}>Reset <Text style={styles.username2}>{username}'s</Text> pending amount to 0.</Text>
                            
                            <View style={styles.alignContainer1}>
                                <Button1  title={`Cancel`} bgColor='red' onPress={() => setShowFormattingModal(false)}/>
                                <Button1  title={`Reset`} bgColor='rgba(0, 128, 0, 0.775)' onPress={approveAll}/>
                            </View>
                        </View>
                    </View>
                </Modal>
                
                {/* target */}
                <Modal
                    visible={showTargetModal}
                    transparent={true}
                    animationType="slide"
                    onRequestClose={() => {setShowTargetModal(false); setAlterTargetAmount("0")}}
                >
                    <View style={styles.modalContainer}>
                        <View style={styles.modalContent}>
                            <Text style={styles.modalTitle}>Change <Text style={styles.username2}>{username}'s</Text> daily target.</Text>
                            <TextInput
                                placeholder="Amount"
                                value={alterTargetAmount}
                                onChangeText={setAlterTargetAmount}
                                style={styles.input}
                                keyboardType="numeric"
                            />
                            
                            <View style={styles.alignContainer1}>
                                <Button1  title={`Cancel`} bgColor='red' onPress={() => {setShowTargetModal(false); setAlterTargetAmount("0")}}/>
                                <Button1  title={`Change Target`} bgColor='rgba(0, 128, 0, 0.775)' onPress={alterTarget}/>
                            </View>
                        </View>
                    </View>
                </Modal>

                {/* in app bal */}
                <Modal
                    visible={showInAppModal}
                    transparent={true}
                    animationType="slide"
                    onRequestClose={() => {setShowInAppModal(false); setNewInAppBal("0")}}
                >
                    <View style={styles.modalContainer}>
                        <View style={styles.modalContent}>
                            <Text style={styles.modalTitle}>Enter new in-app balance for <Text style={styles.username2}>{username}.</Text></Text>
                            <TextInput
                                placeholder="Amount"
                                value={newInAppBal}
                                onChangeText={setNewInAppBal}
                                style={styles.input}
                                keyboardType="numeric"
                            />
                            
                            <View style={styles.alignContainer1}>
                                <Button1  title={`Cancel`} bgColor='red' onPress={() => {setShowInAppModal(false); setNewInAppBal("0")}}/>
                                <Button1  title={`Change value`} bgColor='rgba(0, 128, 0, 0.775)' onPress={ChangeInAppBal}/>
                            </View>
                        </View>
                    </View>
                </Modal>

                {/* format all users to 0 */}
                <Modal
                    visible={showAllUserResetModal}
                    transparent={true}
                    animationType="slide"
                    onRequestClose={() => setShowAllUserResetModal(false)}
                >
                    <View style={styles.modalContainer}>
                        <View style={styles.modalContent}>
                            <Text style={styles.modalTitle}>This is a sensitive action. Please confirm.</Text>
                            
                            <View style={styles.alignContainer1}>
                                <Button1  title={`Cancel`} bgColor='red' onPress={() => setShowAllUserResetModal(false)}/>
                                <Button1  title={`Confirm`} bgColor='rgba(0, 128, 0, 0.775)' onPress={resetAllUsersPendings}/>
                            </View>
                        </View>
                    </View>
                </Modal>






                <Modal transparent={true} visible={loading}>
                    <View style={styles.modalContainer}>
                        <ActivityIndicator size="large" color="rgba(255, 165, 0, 0.775)" />
                        <Text style={styles.loadingText}>Fetching user data...</Text>
                    </View>
                </Modal>
                <Modal transparent={true} visible={updatingData}>
                    <View style={styles.modalContainer}>
                        <ActivityIndicator size="large" color="rgba(255, 165, 0, 0.775)" />
                        <Text style={styles.loadingText}>Updating data...</Text>
                    </View>
                </Modal>
                
            </ScrollView>
        </KeyboardAvoidingView>
    )
}

const styles = StyleSheet.create({
    keyboardView: {
        flex: 1,
    },
    scrollContainer: {
        padding: 0,
    },
    container1: {
        padding: 20,
        backgroundColor: 'rgba(0, 128, 0, 0.075)',
        borderRadius: 20,
        marginBottom: 20,
    },
    container11: {
        padding: 20,
        backgroundColor: 'rgba(128, 0, 0, 0.075)',
        borderRadius: 20,
        marginBottom: 20,
    },
    username: {
        fontWeight: 'bold',
        fontSize: 18,
        marginBottom: 10,
        textDecorationLine: 'underline',
        color: 'green',
    },
    username2: {
        fontWeight: 'bold',
        fontSize: 18,
        marginBottom: 10,
        fontFamily: 'monospace',
        color: 'rgba(255, 165, 0, 0.775)',
    },
    maxAmount: {
        fontWeight: 'bold',
        fontSize: 18,
        marginBottom: 10,
        color: 'green',
        textAlign: 'center',
    },
    activeStatus: {
        fontFamily: 'monospace',
        color: 'rgba(255, 165, 0, 0.775)',
    },
    regText: {
        fontSize: 16,
        fontWeight: 'bold',
        color: 'gray',
        marginBottom: 7.5,
    },
    amounts: {
        fontSize: 18,
        color: 'rgba(255, 165, 0, 0.775)',
        fontWeight: 'bold',
        fontFamily: 'monospace',
    },
    amounts2: {
        fontSize: 18,
        color: 'green',
        fontWeight: 'bold',
        fontFamily: 'monospace',
    },

    alignContainer1: {
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'space-between',
        backgroundColor: "rgb(240,240,240)",
        padding: 10,
        borderRadius: 20,
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
        fontWeight: 'bold',
        marginBottom: 15,
    },
    input: {
        height: 40,
        borderColor: 'rgba(0, 128, 0, 0.175)',
        borderWidth: 1,
        marginBottom: 10,
        paddingLeft: 8,
        borderRadius: 10,
        backgroundColor: '#fff',
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