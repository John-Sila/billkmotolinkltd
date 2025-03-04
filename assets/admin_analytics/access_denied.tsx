import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";
import { KeyboardAvoidingView, Text, View, StatusBar, ScrollView, StyleSheet, Platform } from "react-native";

export default function AnalyticAccessDenied() {
    return (
                <View style={styles.accessDenied}>
                    <Ionicons name="alert" size={22} color="gray"/>
                    <Text>Access Denied</Text>
                </View>
    )
}

const styles = StyleSheet.create({
    keyboardView: {
    flex: 1,

    },
    scrollContainer: {
        padding: 0,
        backgroundColor: 'green',
        height: '100%',
    },
    accessDenied: {
        display: 'flex',
        justifyContent: 'center',
        height: 700,
        width: '100%',
        alignItems: 'center',
    }
})