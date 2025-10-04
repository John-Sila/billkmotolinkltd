export interface WeatherData {
  temperature: number;
  windspeed: number;
  weathercode: number;
  time: string;
}

export async function fetchWeather(lat: number, lon: number): Promise<WeatherData | null> {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,windspeed_10m,weathercode`;

    const response = await fetch(url);

    if (!response.ok) {
      throw new Error("Failed to fetch weather");
    }

    const data = await response.json();

    return {
      temperature: data.current.temperature_2m,
      windspeed: data.current.windspeed_10m,
      weathercode: data.current.weathercode,
      time: data.current.time,
    };
  } catch (error) {
    console.error("Error fetching weather:", error);
    return null;
  }
}
