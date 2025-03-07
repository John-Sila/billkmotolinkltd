import { collection, deleteDoc, doc, getDocs, orderBy, query } from "firebase/firestore";
import { useCallback, useEffect, useState } from "react";
import { KeyboardAvoidingView, Text, View, Alert, StatusBar, ScrollView, StyleSheet, Platform, RefreshControl, Linking, Modal, ActivityIndicator } from "react-native";
import db from "../utilities/firebase_file";
import checkAndUpdateUnpushedAmount from "../utilities/check_increment_dates";
import { useFocusEffect } from "expo-router";
import Button1 from "../utilities/button1";

export default function DamageReports() {
    const [refreshing, setRefreshing] = useState<boolean>(false);
    const [loading, setLoading] = useState<boolean>(false);
    const [deleting, setDeleting] = useState<boolean>(false);
    const [damageReports, setDamageReports] = useState<any>([]);

    useFocusEffect(
        useCallback( () => {
            checkAndUpdateUnpushedAmount();
            FetchDamageReports();
        }, [])
    )

    const onRefresh = async () => {
        setRefreshing(true);
        try {
            await Promise.all([FetchDamageReports(),]);
        } catch (error) {
            console.error("Error refreshing data:", error);
        } finally {
            setRefreshing(false); // Ensures it stops refreshing after function is done
        }
    };

    const FetchDamageReports = async() => {
        try {
            setLoading(true);
            const reportsCollection = collection(db, "reports"); // Reference to users collection
            const querySnapshot = await getDocs(reportsCollection);
            
            const reports = querySnapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            }));
            
            setDamageReports(reports);
            
        } catch (error) {
            console.error('Error fetching reports:', error);
        } finally {
            setLoading(false);
        }
    }
    const openGoogleMaps = (latitude: number, longitude: number) => {
        const url = `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`;
        Linking.openURL(url);
    };

    const deleteReport = async (reportId: string) => {
        try {
            setDeleting(true);
            await deleteDoc(doc(db, "reports", reportId));
            Alert.alert("Success", "Report deleted successfully!");
        } catch (error) {
            console.error("Error deleting report:", error);
            Alert.alert("Error", "Failed to delete report.");
        } finally {
            setDeleting(false);
            FetchDamageReports();
        }
    };

    const clearAllReports = async () => {
        try {
            setDeleting(true);
            const querySnapshot = await getDocs(collection(db, "reports"));
            const deletePromises = querySnapshot.docs.map((reportDoc) =>
                deleteDoc(doc(db, "reports", reportDoc.id))
        );
        
        await Promise.all(deletePromises);
        Alert.alert("Success", "All reports have been deleted.");
        } catch (error) {
            console.error("Error clearing reports:", error);
            Alert.alert("Error", "Failed to clear reports.");
        } finally {
            setDeleting(false);
            FetchDamageReports();
        }
    };
      
      
    return (
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardView}>
            <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled"
            refreshControl={
                <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={["green"]} />
            }>
                <View style={{display: 'flex', flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center'}}>
                    <Text style={styles.labels1}>Rider Damage Reports: </Text>
                    <Button1
                                        title={`Clear`}
                                        bgColor="red"
                                        onPress={() =>
                                            Alert.alert(
                                              "Confirm Delete",
                                              "Delete all reports?",
                                              [
                                                { text: "Cancel", style: "cancel" },
                                                { text: "Clear", style: "destructive", onPress: () => clearAllReports() },
                                              ]
                                            )}
                                        />
                </View>
                {
                    // damageReports &&
                    damageReports.map((damageReport: any, key: number) => (
                        <View key={key} style={styles.damageReportContainer}>
                            <Text style={styles.labels3}><Text style={styles.innerText2}>{damageReport.rider ? damageReport.rider : "Unknown Rider"}</Text></Text>
                            <Text style={styles.labels2}>Report Type: <Text style={styles.innerText}>{damageReport.report_type ? damageReport.report_type : "Unindentified"}</Text></Text>
                            <Text style={styles.labels2}>Description: <Text style={styles.innerText}>{damageReport.report_description ? damageReport.report_description : "Unindentified"}</Text></Text>
                            <Text style={styles.labels2}>Involved Bike: <Text style={styles.innerText}>{damageReport.bike ? damageReport.bike : "Unknown Bike"}</Text></Text>
                            <Text style={styles.labels2}>
                                Time of Report:{' '}
                                <Text style={styles.innerText}>
                                    {
                                        damageReport.report_time
                                        ? new Date(damageReport.report_time).toLocaleString()
                                        : 'Unidentified'
                                    }
                                </Text>
                            </Text>

                            <Button1
                                        title={`Open Location`}
                                        bgColor="green"
                                        onPress={() => openGoogleMaps(damageReport.location?.latitude, damageReport.location?.longitude)}
                                        />
                            <Button1
                                        title={`Delete Report`}
                                        bgColor="red"
                                        onPress={() =>
                                            Alert.alert(
                                              "Confirm Delete",
                                              "Are you sure you want to delete this report?",
                                              [
                                                { text: "Cancel", style: "cancel" },
                                                { text: "Delete", style: "destructive", onPress: () => deleteReport(damageReport.id) },
                                              ]
                                            )}
                                        />
                        </View>
                    ))
                }



                <Modal transparent={true} visible={deleting}>
                    <View style={styles.modalContainer}>
                        <ActivityIndicator size="large" color="rgba(255, 165, 0, 0.775)" />
                        <Text style={styles.loadingText}>Deleting...</Text>
                    </View>
                </Modal>
                <Modal transparent={true} visible={loading}>
                    <View style={styles.modalContainer}>
                        <ActivityIndicator size="large" color="rgba(255, 165, 0, 0.775)" />
                        <Text style={styles.loadingText}>Fetching damage reports...</Text>
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
        color: 'gray',
        fontSize: 18,
        marginVertical: 5,
    },
    labels3: {
        fontWeight: 'bold',
        color: 'gray',
        fontSize: 20,
        marginVertical: 5,
    },
    damageReportContainer: {
        flex: 1,
        justifyContent: 'center',
        backgroundColor: "rgba(0, 78, 0, 0.035)",
        marginVertical: 20,
        padding: 20,
        borderRadius: 20,
    },
    innerText: {
        fontSize: 16,
        color: "rgba(255, 165, 0, 0.775)",
        fontFamily: "monospace",
        fontWeight: "bold",
    },
    innerText2: {
        fontSize: 18,
        color: "green",
        fontFamily: "monospace",
        fontWeight: "bold",
        textDecorationLine: "underline",
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
})