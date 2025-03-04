import { useCallback, useEffect, useState } from "react";
import { KeyboardAvoidingView, Text, View, StatusBar, ScrollView, StyleSheet, Platform, RefreshControl, Alert, Modal, ActivityIndicator, TouchableOpacity, Vibration } from "react-native";
import { Picker } from '@react-native-picker/picker';
import { useFocusEffect } from "expo-router";
import checkAndUpdateUnpushedAmount from "../utilities/check_increment_dates";
import { collection, getDoc, getDocs, orderBy, query } from "firebase/firestore";
import db from "../utilities/firebase_file";
import CheckIfThisUserIsStillLoggedIn from "../utilities/check_login_status";
import { Ionicons } from "@expo/vector-icons";
import { Switch } from 'react-native-switch';

export default function ClockOutReports() {
    const [refreshing, setRefreshing] = useState<boolean>(false);
    const [loading, setLoading] = useState<boolean>(false);
    const [filterOn, setFilterOn] = useState<boolean>(false);
    const [usersList, setUsersList] = useState<any>([]);
    const [months, setMonths] = useState<any>([])
    const [selectedMonth, setSelectedMonth] = useState<string>("");
    const [currentMonth, setCurrentMonth] = useState<string>("");
    const [pathStr, setPathStr] = useState<string>("");
    const [days, setDays] = useState<string[]>(["01","02","03","04","05","06","07","08","09","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31",]);
    const [selectedDate, setSelectedDate] = useState<string>("");
    const [years, setYears] = useState<number[]>([]);

    const [allUsers, setAllUsers] = useState<any[]>([]);



    const [selectedYear, setSelectedYear] = useState<string>("");
    const [expandedUsers, setExpandedUsers] = useState<string[]>([]);

    const toggleUser = (uid: string) => {
        if (expandedUsers.includes(uid)) {
            setExpandedUsers(expandedUsers.filter(id => id !== uid));
        } else {
            setExpandedUsers([...expandedUsers, uid]);
        }
    };








    useFocusEffect(
        useCallback( () => {
            CheckIfThisUserIsStillLoggedIn();
            checkAndUpdateUnpushedAmount();
            fetchUsersAndClockOuts();
            loadMonths();
            fetchUsers();
        }, [])
    )

    useEffect( () => {loadMonths();}, [])


    const toggleSwitch = () => {
        Vibration.vibrate(50);
        setFilterOn(previousState => !previousState)
    };
    useEffect( () => {
        setPathStr(`${selectedDate}-${selectedMonth}-${selectedYear}`);
    }, [selectedDate, selectedMonth, selectedYear, filterOn])


    const fetchUsers = async () => {
        setLoading(true);
        try {
            const usersQuery = query(collection(db, 'users'));
            const querySnapshot = await getDocs(usersQuery);
            const users = querySnapshot.docs.map((doc: any) => doc.data());
            setUsersList(users);
        } catch (error) {
            Alert.alert('Error', `Failed to fetch user emails. ${error}}`);
        } finally {
            setLoading(false);
        }
    };

    const onRefresh = async () => {
        setRefreshing(true);
        try {
            await Promise.all([fetchUsersAndClockOuts(),]);
        } catch (error) {
            console.error("Error refreshing data:", error);
        } finally {
            setRefreshing(false); // Ensures it stops refreshing after function is done
        }
    };

    const loadMonths = () => {
        const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        const monthDigit = new Date().getMonth();
        const dateDigit = new Date().getDate();
        setSelectedDate(dateDigit.toString().padStart(2, "0"));
        
        const thisMonth = months[monthDigit];
        setCurrentMonth(thisMonth);
        setMonths(months);
        setSelectedMonth(thisMonth.substring(0, 3));

        const currentYear = new Date().getFullYear();
        const lastFiveYears = Array.from({ length: 5 }, (_, i) => currentYear - i);
        setYears(lastFiveYears);
        setSelectedYear(currentYear.toString());
    }

    const formatCurrency = (amount: number) => {
        return new Intl.NumberFormat('en-KE', {
          style: 'currency',
          currency: 'KES',
          minimumFractionDigits: 0
        }).format(amount);
    };

    const fetchUsersAndClockOuts = async () => {
        try {
            setLoading(true);
            const usersSnapshot = await getDocs(collection(db, "users"));
            const usersData: any[] = [];
        
            for (const userDoc of usersSnapshot.docs) {
                const userData = { uid: userDoc.id, ...userDoc.data() };
        
                // Fetch the user's clock_outs subcollection
                const clockOutsSnapshot = await getDocs(
                collection(db, "users", userDoc.id, "clock_outs")
                );
        
                const clockOuts: any[] = [];
                clockOutsSnapshot.forEach((clockOutDoc) => {
                clockOuts.push({ id: clockOutDoc.id, ...clockOutDoc.data() });
                });
        
                // Add clock_outs array into the user data
                usersData.push({
                ...userData,
                clock_outs: clockOuts,
                });
            }
        
            setAllUsers(usersData); // Now includes both user data and their clock_outs
        } catch (error: any) {
            Alert.alert("Error fetching data:", error);
        } finally {
            setLoading(false);
        }
    };
      
  

    return (
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
            <StatusBar
                barStyle="light-content"
                backgroundColor="green"
                />
            <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled"
                refreshControl={
                    <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={["green"]} />
                }
            >
                <Text style={styles.labels1}>Rider Activity Reports: </Text>
                <View
                style={{
                    backgroundColor: 'rgba(255, 165, 0, 0.125)',
                    padding: 10,
                    marginVertical: 20,
                    borderRadius: 20,
                }}>
                    <View style={styles.alignContainer1}>
                        <Text style={styles.labels}>DD/M: </Text>

                        <View style={{ 
                            borderWidth: 1, 
                            borderColor: '#ccc',
                            borderRadius: 10,
                            overflow: 'hidden',
                            backgroundColor: '#fff',
                            marginVertical: 0,
                            width: '40%',
                        }}>
                            <Picker
                                selectedValue={selectedDate}
                                onValueChange={(itemValue) => setSelectedDate(itemValue)}
                                style={styles.picker}
                            >
                                {days.map((day: string, index: number) => (
                                    <Picker.Item
                                        key={index}
                                        label={day}
                                        value={day}
                                    />
                                    ))
                                }
                            </Picker>

                        </View>

                        <View style={{ 
                            borderWidth: 1, 
                            borderColor: '#ccc', 
                            borderRadius: 10, 
                            overflow: 'hidden', 
                            backgroundColor: '#fff', 
                            marginVertical: 0,
                            width: '40%',
                        }}>
                            <Picker
                                selectedValue={selectedMonth}
                                onValueChange={(itemValue) => setSelectedMonth(itemValue)}
                                style={styles.picker}
                            >
                                {months.map((option: string, index: number) => (
                                    <Picker.Item
                                        key={index}
                                        label={option}
                                        value={option.substring(0, 3)}
                                    />
                                    ))
                                }
                            </Picker>

                        </View>

                    </View>


                    {/* <View style={styles.alignContainer1}>
                        <Text style={styles.labels}>User: </Text>

                        <View style={{ 
                            borderWidth: 1, 
                            borderColor: '#ccc', 
                            borderRadius: 10, 
                            overflow: 'hidden', 
                            backgroundColor: '#fff', 
                            marginVertical: 0,
                            width: '70%',
                        }}>
                            <Picker
                                selectedValue={selectedUser}
                                onValueChange={(itemValue) => setSelectedUser(itemValue)}
                                style={styles.picker}
                            >
                                {usersList.map((user: any, index: number) => (
                                    <Picker.Item
                                        key={index}
                                        label={user.username}
                                        value={user.username}
                                    />
                                    ))
                                }
                            </Picker>
                            
                        </View>

                    </View> */}


                    <View style={styles.alignContainer1}>
                        <Text style={styles.labels}>Year: </Text>

                        <View style={{ 
                            borderWidth: 1, 
                            borderColor: '#ccc', 
                            borderRadius: 10, 
                            overflow: 'hidden', 
                            backgroundColor: '#fff', 
                            marginVertical: 0,
                            width: '70%',
                        }}>
                            <Picker
                                selectedValue={selectedYear}
                                onValueChange={(itemValue) => setSelectedYear(itemValue)}
                                style={styles.picker}
                            >
                                {years.map((year: any, index: number) => (
                                    <Picker.Item
                                        key={index}
                                        label={year}
                                        value={year}
                                    />
                                    ))
                                }
                            </Picker>
                            
                        </View>

                    </View>
                </View>


                <View style={styles.switchContainer}>
                    <Text style={filterOn ? styles.label1 : styles.label2}>Filtration</Text>
                    <Switch
                        value={filterOn}
                        onValueChange={toggleSwitch}
                        disabled={false}
                        activeText={'On'}
                        inActiveText={'Off'}
                        circleSize={30}
                        barHeight={20}
                        circleBorderWidth={1}
                        backgroundActive={'#81b0ff'}
                        backgroundInactive={'#767577'}
                        circleActiveColor={'rgba(255, 165, 0, 1)'}
                        circleInActiveColor={'#f4f3f4'}
                        changeValueImmediately={true} // If you want instant change
                        innerCircleStyle={{ alignItems: "center", justifyContent: "center" }} // for extra customization
                        />
                </View>


                <View style={{
                    // backgroundColor: 'rgba(255, 165, 0, 0.125)',
                    padding: 10,
                    marginVertical: 20,
                    borderRadius: 20,
                    display: 'flex',
                    flexDirection: 'column',
                }}>
                    {
                        allUsers.map((user: any, userIndex: number) => (
                            // exclude deleted users
                            !(user.is_deleted === true) && !(user.role === 'CEO') &&
                            <View key={user.uid} style={styles.outerDiv}>
                                <TouchableOpacity onPress={() => toggleUser(user.uid)}>
                                    <Text style={expandedUsers.includes(user.uid) ? styles.usernameEngaged : styles.usernameDisengaged}>
                                        {user.username}
                                        {expandedUsers.includes(user.uid) ?
                                        <Ionicons name="caret-up-outline" size={22}/>
                                        :
                                        <Ionicons name="caret-down-outline" size={22}/>
                                        }
                                    </Text>
                                </TouchableOpacity>

                                {expandedUsers.includes(user.uid) && (

                                    <View>
                                        {
                                            !filterOn &&

                                            user.clock_outs && Object.entries(user.clock_outs).map(([date, clockOutData]: [string, any]) => (
                                                <View key={date} style={styles.innerDiv}>
                                                    <Text style={styles.date}>📆 Date: {clockOutData.id}</Text>
                                                    <View style={styles.evenInnerDiv}>
                                                        <Text>
                                                            <Text style={styles.innerText1}>⁕ Gross Income: </Text>
                                                            <Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.gross ? clockOutData.gross : "00"))}.00 </Text>
                                                        </Text>
                                                        <Text>
                                                            <Text style={styles.innerText1}>⁕ Net Income: </Text>
                                                            <Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.net ? clockOutData.net : "00"))}.00</Text>
                                                        </Text>
                                                        <Text><Text style={styles.innerText1}>⁕ Expenses: </Text></Text>
                                                        <View style={styles.evenInnerInnerDiv}>
                                                            <Text>
                                                                <Text style={styles.innerText1}>● Battery Swap: </Text>
                                                                <Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.expenses?.battery_swap ? clockOutData.expenses?.battery_swap : "00"))}.00</Text>
                                                            </Text>
                                                            <Text><Text style={styles.innerText1}>● Traffic Police: </Text><Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.expenses?.police ? clockOutData.expenses?.police : "00"))}.00</Text></Text>
                                                            <Text>
                                                                <Text style={styles.innerText1}>● Lunch: </Text>
                                                                <Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.expenses?.lunch ? clockOutData.expenses?.lunch : "00"))}.00</Text>
                                                            </Text>
                                                            <Text>
                                                                <Text style={styles.innerText1}>● Other: </Text>
                                                                <Text style={styles.innerText2}>
                                                                    {clockOutData.expenses?.other?.name 
                                                                        ? ` (${clockOutData.expenses.other.name})` 
                                                                        : ""} 
                                                                    {formatCurrency(parseInt(clockOutData.expenses?.other?.amount ? clockOutData.expenses?.other?.amount : "00"))}.00

                                                                </Text>
                                                            </Text>

                                                        </View>

                                                    </View>
                                                </View>
                                            ))
                                        }
                                        {
                                            filterOn &&
                                            user.clock_outs && Object.entries(user.clock_outs).map(([date, clockOutData]: [string, any]) => (
                                                clockOutData.id === pathStr &&
                                                <View key={date} style={styles.innerDiv}>
                                                    <Text style={styles.date}>📆 Date: {clockOutData.id}</Text>
                                                    <View style={styles.evenInnerDiv}>
                                                        <Text>
                                                            <Text style={styles.innerText1}>⁕ Gross Income: </Text>
                                                            <Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.gross ? clockOutData.gross : "00"))}.00 </Text>
                                                        </Text>
                                                        <Text>
                                                            <Text style={styles.innerText1}>⁕ Net Income: </Text>
                                                            <Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.net ? clockOutData.net : "00"))}.00</Text>
                                                        </Text>
                                                        <Text><Text style={styles.innerText1}>⁕ Expenses: </Text></Text>
                                                        <View style={styles.evenInnerInnerDiv}>
                                                            <Text>
                                                                <Text style={styles.innerText1}>● Battery Swap: </Text>
                                                                <Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.expenses?.battery_swap ? clockOutData.expenses?.battery_swap : "00"))}.00</Text>
                                                            </Text>
                                                            <Text><Text style={styles.innerText1}>● Traffic Police: </Text><Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.expenses?.police ? clockOutData.expenses?.police : "00"))}.00</Text></Text>
                                                            <Text>
                                                                <Text style={styles.innerText1}>● Lunch: </Text>
                                                                <Text style={styles.innerText2}>{formatCurrency(parseInt(clockOutData.expenses?.lunch ? clockOutData.expenses?.lunch : "00"))}.00</Text>
                                                            </Text>
                                                            <Text>
                                                                <Text style={styles.innerText1}>● Other: </Text>
                                                                <Text style={styles.innerText2}>
                                                                    {clockOutData.expenses?.other?.name 
                                                                        ? ` (${clockOutData.expenses.other.name})` 
                                                                        : ""} 
                                                                    {formatCurrency(parseInt(clockOutData.expenses?.other?.amount ? clockOutData.expenses?.other?.amount : "00"))}.00

                                                                </Text>
                                                            </Text>

                                                        </View>

                                                    </View>
                                                </View>
                                            ))
                                        }

                                    </View>
                                )}


                                {/* </ScrollView> */}

                            </View>


                        ))
                    }

                    {
                        allUsers.map((user: any, key: number) => (
                            user.role === 'CEO' &&
                            <View>
                                <TouchableOpacity onPress={() => toggleUser(user.uid)}>
                                    <View style={{display: 'flex', flexDirection: 'row', alignItems: 'center'}}>
                                        <Text style={expandedUsers.includes(user.uid) ? styles.usernameEngaged : styles.usernameDisengaged}>{user.username} (CEO -- Unmanaged)</Text>
                                        <Ionicons name="ban" color={"red"} size={22}/>
                                    </View>
                                </TouchableOpacity>
                            </View>
                        ))
                    }

                </View>
                
            </ScrollView>


            <Modal transparent={true} visible={loading}>
                <View style={styles.modalContainer}>
                    <ActivityIndicator size="large" color="rgba(255, 165, 0, 0.775)" />
                    <Text style={styles.loadingText}>Getting data...</Text>
                </View>
            </Modal>

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
    container: { margin: 20 },
    label: { marginBottom: 10, fontSize: 16 },
    labels: {
        fontWeight: 'bold',
        color: 'gray',
    },
    labels1: {
        fontWeight: 'bold',
        color: 'gray',
        fontSize: 22,
    },
    alignContainer1: {
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'space-between',
        backgroundColor: "rgb(240,240,240)",
        padding: 10,
        marginVertical: 10,
        borderRadius: 20,
        alignItems: 'center',
    },
    picker: {
      height: 50,
      width: '100%',
      backgroundColor: 'rgb(220, 220,220)',
      borderRadius: 10,
      fontWeight: 'bold',
    },
    switchContainer: {
        display: 'flex',
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'flex-end',
        paddingRight: 20,

    },
    label1: {
        fontSize: 16,
        fontWeight: 'bold',
        color: 'green',
        marginRight: 20,
        
    },
    label2: {
        fontSize: 16,
        fontWeight: 'bold',
        marginRight: 20,
        color: 'gray',

    },




    outerDiv: {
        backgroundColor: 'rgb(225, 225, 225)',
        marginBottom: 30,
        padding: 20,
        borderRadius: 20,
    },
    innerDiv: {
        backgroundColor: 'rgb(225, 225, 225)',
        marginVertical: 10,
        paddingLeft: 20,
        borderRadius: 20
    },
    evenInnerDiv: {
        backgroundColor: 'rgb(225, 225, 225)',
        // marginVertical: 10,
        paddingLeft: 20,
        borderRadius: 20
    },
    evenInnerInnerDiv: {
        paddingLeft: 20,
        borderRadius: 20
    },
    innerText1: {
        fontWeight: 'bold',
        color: 'gray',
    },
    innerText2: {
        fontFamily: 'monospace',
        fontSize: 16,
        fontWeight: 'bold',
        color: 'green',
    },
    usernameEngaged: {
        fontWeight: 'bold',
        fontSize: 17,
        fontFamily: 'monospace',
        color: 'green',
        display: 'flex',
        flexDirection: 'row',
        alignItems: 'center',
        marginRight: 5,
    },
    usernameDisengaged: {
        fontWeight: 'bold',
        fontSize: 17,
        fontFamily: 'monospace',
        color: 'rgba(255, 165, 0, 0.775)',
        marginRight: 5,
    },
    date: {
        fontWeight: 'bold',
        fontSize: 15,
        fontFamily: 'monospace',
        color: 'red',
        textDecorationLine: 'underline',
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