import { useEffect, useState } from "react";
import { fetchUser, type UserData } from "../services/userService";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import PrimaryLoadingFragment from "../assets/PrimaryLoading";
import { fetchWeather, type WeatherData } from "../services/weatherService";
import { formatDateWithSuperscript, getGreeting, parseCurrency } from "../assets/publicFunctions";
import NoUserFound from "../assets/NoUserFound";
import toast, { Toaster } from "react-hot-toast";


interface LocationData {
  city?: string;
  country?: string;
}

export default function Home() {
  const [user, setUser] = useState<UserData | null>(null);
  const [loading, setLoading] = useState(true);
  const [uid, setUid] = useState<string | null>(null);
  const [weather, setWeather] = useState<WeatherData | null>(null);
  const [weatherError, setWeatherError] = useState<string | null>(null);
  const [location, setLocation] = useState<LocationData | null>(null);
  
  //set uid on auth state change
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
      const data = await fetchUser(uid);
      setUser(data);
      setLoading(false);
    }

    loadUser();
  }, [uid]);

  // fetch weather
    useEffect(() => {
        if (!navigator.geolocation) {
        setWeatherError("Geolocation not supported by this browser.");
        setLoading(false);
        return;
        }

        navigator.geolocation.getCurrentPosition(
          async (pos) => {
              const { latitude, longitude } = pos.coords;
              const data = await fetchWeather(latitude, longitude);
              setWeather(data);
              try {
                const geoRes = await fetch(
                  `https://nominatim.openstreetmap.org/reverse?lat=${latitude}&lon=${longitude}&format=json&addressdetails=1`
                );
                const geoData = await geoRes.json();
                console.log("Nominatim geo response:", geoData);

                setLocation({
                  city: geoData.address.city || geoData.address.town || geoData.address.village || "Unknown",
                  country: geoData.address.country || "",
                });

              } catch (err) {
                console.error("Error fetching reverse geocoding:", err);
                setLocation({ city: `${err}`, country: "" });
              }
              setLoading(false);
          },
          (err) => {
              setWeatherError("Failed to get location: " + err.message);
              setLoading(false);
          }
        );
    }, []);


  if (loading) return <PrimaryLoadingFragment />;

  if (!user) return <NoUserFound />;
  
  const today = new Date().toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
  });

  return (
    <div className="home-container">
      <div><Toaster /></div>

      {/* greetings */}
      <p className="greetings">{getGreeting()} {user.userName},</p>

      <div className="div1">
        {/* weather card */}
        <div className="weather-card">
          <div className="container">
            <div className="cloud front">
              <span className="left-front"></span>
              <span className="right-front"></span>
            </div>
            <span className="sun sunshine"></span>
            <span className="sun"></span>
            <div className="cloud back">
              <span className="left-back"></span>
              <span className="right-back"></span>
            </div>
          </div>

          <div className="card-header">
            <span>{location?.city}<br />{location?.country}</span>
            <span>{today}</span>
          </div>

          <span className="temp">{weather?.temperature}°</span>

          <div className="temp-scale">
            <span>Celcius</span>
          </div>
        </div>

        {/* id number */}
        <div className="card-container">
          <div className="credit-card">
            <div className="magnetic-strip"></div>
            <div className="inner">
              <div className="card-number">
                <div className="left">
                  <label className="number-label">BILLK MOTOLINK LTD</label>
                  <span>{user.idNumber}</span>
                </div>
                <div className="left">
                  <svg
                      version="1.1"
                      className="chip"
                      xmlns="http://www.w3.org/2000/svg"
                      xmlnsXlink="http://www.w3.org/1999/xlink"
                      x="0px"
                      y="0px"
                      width="50px"
                      height="50px"
                      viewBox="0 0 50 50"
                      xml:space="preserve"
                    >
                      <image
                        width="50"
                        height="50"
                        x="0"
                        y="0"
                        href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
                        AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAB6VBMVEUAAACNcTiVeUKVeUOY
                        fEaafEeUeUSYfEWZfEaykleyklaXe0SWekSZZjOYfEWYe0WXfUWXe0WcgEicfkiXe0SVekSXekSW
                        ekKYe0a9nF67m12ZfUWUeEaXfESVekOdgEmVeUWWekSniU+VeUKVeUOrjFKYfEWliE6WeESZe0GS
                        e0WYfES7ml2Xe0WXeESUeEOWfEWcf0eWfESXe0SXfEWYekSVeUKXfEWxklawkVaZfEWWekOUekOW
                        ekSYfESZe0eXekWYfEWZe0WZe0eVeUSWeETAnmDCoWLJpmbxy4P1zoXwyoLIpWbjvXjivnjgu3bf
                        u3beunWvkFWxkle/nmDivXiWekTnwXvkwHrCoWOuj1SXe0TEo2TDo2PlwHratnKZfEbQrWvPrWua
                        fUfbt3PJp2agg0v0zYX0zYSfgkvKp2frxX7mwHrlv3rsxn/yzIPgvHfduXWXe0XuyIDzzISsjVO1
                        lVm0lFitjVPzzIPqxX7duna0lVncuHTLqGjvyIHeuXXxyYGZfUayk1iyk1e2lln1zYTEomO2llrb
                        tnOafkjFpGSbfkfZtXLhvHfkv3nqxH3mwXujhU3KqWizlFilh06khk2fgkqsjlPHpWXJp2erjVOh
                        g0yWe0SliE+XekShhEvAn2D///+gx8TWAAAARnRSTlMACVCTtsRl7Pv7+vxkBab7pZv5+ZlL/UnU
                        /f3SJCVe+Fx39naA9/75XSMh0/3SSkia+pil/KRj7Pr662JPkrbP7OLQ0JFOijI1MwAAAAFiS0dE
                        orDd34wAAAAJcEhZcwAACxMAAAsTAQCanBgAAAAHdElNRQfnAg0IDx2lsiuJAAACLElEQVRIx2Ng
                        GAXkAUYmZhZWPICFmYkRVQcbOwenmzse4MbFzc6DpIGXj8PD04sA8PbhF+CFaxEU8iWkAQT8hEVg
                        OkTF/InR4eUVICYO1SIhCRMLDAoKDvFDVhUaEhwUFAjjSUlDdMiEhcOEItzdI6OiYxA6YqODIt3d
                        I2DcuDBZsBY5eVTr4xMSYcyk5BRUOXkFsBZFJTQnp6alQxgZmVloUkrKYC0qqmji2WE5EEZuWB6a
                        lKoKdi35YQUQRkFYPpFaCouKIYzi6EDitJSUlsGY5RWVRGjJLyxNy4ZxqtIqqvOxaVELQwZFZdkI
                        JVU1RSiSalAt6rUwUBdWG1CP6pT6gNqwOrgCdQyHNYR5YQFhDXj8MiK1IAeyN6aORiyBjByVTc0F
                        qBoKWpqwRCVSgilOaY2OaUPw29qjOzqLvTAchpos47u6EZyYnngUSRwpuTe6D+6qaFQdOPNLRzOM
                        1dzhRZyW+CZouHk3dWLXglFcFIflQhj9YWjJGlZcaKAVSvjyPrRQ0oQVKDAQHlYFYUwIm4gqExGm
                        BSkutaVQJeomwViTJqPK6OhCy2Q9sQBk8cY0DxjTJw0lAQWK6cOKfgNhpKK7ZMpUeF3jPa28BCET
                        amiEqJKM+X1gxvWXpoUjVIVPnwErw71nmpgiqiQGBjNzbgs3j1nus+fMndc+Cwm0T52/oNR9lsdC
                        S24ra7Tq1cbWjpXV3sHRCb1idXZ0sGdltXNxRateRwHRAACYHutzk/2I5QAAACV0RVh0ZGF0ZTpj
                        cmVhdGUAMjAyMy0wMi0xM1QwODoxNToyOSswMDowMEUnN7UAAAAldEVYdGRhdGU6bW9kaWZ5ADIw
                        MjMtMDItMTNUMDg6MTU6MjkrMDA6MDA0eo8JAAAAKHRFWHRkYXRlOnRpbWVzdGFtcAAyMDIzLTAy
                        LTEzVDA4OjE1OjI5KzAwOjAwY2+u1gAAAABJRU5ErkJggg=="
                      ></image>
                  </svg>
                </div>
              </div>
              <div className="card-details">
                <div className="card-holder">
                  <label>CARDHOLDER NAME</label>
                  <span className="card-name">{user.userName}, {user.userRank}</span>
                  <br />
                  <span className="card-name">{user.email}</span>
        
                </div>
                <div className="card-expiry">
                  <label>EXPIRY DATE</label>
                  <span className="card-date">Going Concern</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* user data information */}
        <div className="notification">
            <div className="notiglow"></div>
            <div className="notiborderglow"></div>
            <div className="notititle">From your profile,</div>
            <div className="notibody">
              <table>
                <thead>
                  <th>Parameter</th>
                  <th>Count</th>
                </thead>
                <tbody>
                  <tr>
                    <td>Amount pending approval</td>
                    <td>{parseCurrency(user.pendingAmount ?? 0)}</td>
                  </tr>
                  <tr>
                    <td>Last clockout date</td>
                    <td>{formatDateWithSuperscript(user.lastClockDate)}</td>
                  </tr>
                  <tr>
                    <td>Net clocked</td>
                    <td>{parseCurrency(user.netClockedLastly ?? 0)}</td>
                  </tr>
                  <tr>
                    <td>Daily target</td>
                    <td>{parseCurrency(user.dailyTarget ?? 0)}</td>
                  </tr>
                  <tr>
                    <td>Sunday working status</td>
                    <td>{user.isWorkingOnSunday ? "True" : "false"}</td>
                  </tr>
                  <tr>
                    <td>Clocked in status</td>
                    <td>{user.isClockedIn ? "True" : "false"}</td>
                  </tr>
                  <tr>
                    <td>Requirements</td>
                    <td>{user.requirements ? Object.keys(user.requirements).length : 0}</td>
                  </tr>
                </tbody>
              </table>
            </div>
        </div>
      </div>
    </div>
  );
}
