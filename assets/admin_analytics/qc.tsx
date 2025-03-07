import { collection, getDocs } from "firebase/firestore";
import { useCallback, useState } from "react";
import { KeyboardAvoidingView, Text, View, Dimensions,  StatusBar, ScrollView, StyleSheet, Platform, RefreshControl, Modal, ActivityIndicator } from "react-native";
import db from "../utilities/firebase_file";
import { useFocusEffect } from "expo-router";
import { LineChart } from 'react-native-chart-kit';

export default function QualityControl() {

    
    const [refreshing, setRefreshing] = useState<boolean>(false);
    const [loading, setLoading] = useState<boolean>(false);
    const [users, setUsers] = useState<any>([]);
    const [months, setMonths] = useState<any>([]);

    useFocusEffect(
        useCallback( () => {
            (async () => {
                await fetchData();
                getLastMonths();
                await usersWithFullDeviations();
            })();
        }, [])
    )

    const screenWidth = Dimensions.get("window").width;

    const onRefresh = async () => {
        setRefreshing(true);
        try {
            await Promise.all([fetchData(),]);
        } catch (error) {
            console.error("Error refreshing data:", error);
        } finally {
            setRefreshing(false); // Ensures it stops refreshing after function is done
        }

    };

   

    const fetchData = async () => {
        try {
            if (!refreshing) {
                setLoading(true);
            }
            const usersCollection = collection(db, "users"); // Reference to users collection
            const querySnapshot = await getDocs(usersCollection);
            
            // Map through documents and extract user data
            const usersList = querySnapshot.docs
                .map((doc: any) => ({
                    id: doc.id, // UID
                    ...doc.data(), // Other user data
                }))
                .filter((user: any) => user.role !== "CEO" && user.is_deleted !== true); // 🔥 Filter here
        
            setUsers(usersList); // Update state with filtered users
        } catch (error) {
            console.error("Error fetching users:", error);
        } finally {
            setLoading(false);
        }
    };
    

    const getLastMonths = () => {
        const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const months = [];
        const now = new Date();
      
        for (let i = 0; i < 11; i++) {
          const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
          months.unshift(monthNames[date.getMonth()]);
        }
        setMonths(months);
      };

      const usersWithFullDeviations = users.map((user: any) => {
        const fullDeviations = months.map((month: any) => ({
          month,
          value: user.deviation_from_target?.[month] || 0
        }));
        return {
          username: user.username,
          deviations: fullDeviations
        };
      });
      
      

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
                <Text style={styles.labels1}>Data Visualization:</Text>
                <Text style={styles.labels2}>1. Amounts earned below or above target in the last 11 months:</Text>
                




                <ScrollView
                    refreshControl={
                        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={["green"]} />
                    }
                >
                    {
                    usersWithFullDeviations
                    .filter((user: any) => user.role !== "CEO")
                    .map((user: any, index: number) => {
                        const chartData = {
                            labels: months,
                            datasets: [
                            {
                                data: user.deviations.map((item: any) => item.value),
                                color: () => '#FF5733', // optional
                            },
                            ],
                        };

                        return (
                            <View key={index} style={{ marginVertical: 20 }}>
                            <Text style={{ fontSize: 18, fontWeight: 'bold', marginBottom: 10, color: 'green', textDecorationLine: 'underline', fontFamily: 'monospace' }}>
                                {user.username}
                            </Text>

                            <LineChart
                                data={chartData}
                                width={screenWidth - 32}
                                height={220}
                                chartConfig={{
                                    backgroundColor: '#ffffff',
                                    backgroundGradientFrom: '#ffffff',
                                    backgroundGradientTo: '#ffffff',
                                    decimalPlaces: 1,
                                    color: () => '#000',
                                    labelColor: () => '#888',
                                }}
                                bezier
                                style={{
                                marginVertical: 8,
                                borderRadius: 16,
                                }}
                            />
                            </View>
                        );
                    })}
                </ScrollView>












                <Modal transparent={true} visible={loading}>
                    <View style={styles.modalContainer}>
                        <ActivityIndicator size="large" color="rgba(255, 165, 0, 0.775)" />
                        <Text style={styles.loadingText}>Fetching user data...</Text>
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
    labels1: {
        fontWeight: 'bold',
        color: 'gray',
        fontSize: 22,
    },
    labels2: {
        fontWeight: 'bold',
        color: 'red',
        fontSize: 18,
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