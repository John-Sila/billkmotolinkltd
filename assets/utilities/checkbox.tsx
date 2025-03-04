import React from "react";
import Icon from "react-native-vector-icons/MaterialIcons";
import { TouchableOpacity, Text, StyleSheet } from "react-native";

interface CheckBoxProps {
  selected: boolean;
  onPress: () => void;
  style?: object;
  textStyle?: object;
  size?: number;
  color?: string;
  text?: string;
}

const CheckBox: React.FC<CheckBoxProps> = ({
  selected,
  onPress,
  style,
  textStyle,
  size = 30,
  color = "#211f30",
  text = "",
  ...props
}) => (
  <TouchableOpacity style={[styles.checkBox, style]} onPress={onPress} {...props}>
    <Icon size={size} color={color} name={selected ? "check-box" : "check-box-outline-blank"} />
    {text ? <Text style={[styles.text, textStyle]}>{text}</Text> : null}
  </TouchableOpacity>
);

const styles = StyleSheet.create({
  checkBox: {
    flexDirection: "row",
    alignItems: "center",
  },
  text: {
    marginLeft: 8,
    fontSize: 16,
    color: "#000",
  },
});

export default CheckBox;
