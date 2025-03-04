import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';

interface MyButtonProps {
    onPress: () => void;
    title: string;
    bgColor?: string;
}
const Button1: React.FC<MyButtonProps> = ({ onPress, title, bgColor = 'rgb(0, 25, 240)' }) => {
  return (
    <TouchableOpacity style={[styles.ThisButton, { backgroundColor: bgColor }]} onPress={onPress}>
      <Text style={styles.ButtonText}>{title}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  ThisButton: {
    padding: 12.5,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 5,
    marginTop: 5,
    minWidth: 75,
    opacity: .75,

  },
  ButtonText: {
    color: '#fff',
    fontSize: 16,
  },
});

export default Button1;
