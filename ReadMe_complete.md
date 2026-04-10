# 🍎 Orchard Climate Monitor (Automated)

An automated data pipeline and **Shiny Decision Support System** that tracks weather conditions, Growing Degree Days (GDD), and frost events for specific orchard locations using German Weather Service (DWD) data.

## 🚀 How it Works
This project is fully automated using **GitHub Actions**. The system operates on a "hands-off" cycle:

1.  **Daily Trigger:** Every morning at **04:00 UTC**, a GitHub Action wakes up a virtual environment.
2.  **Data Pull:** The "robot" runs `update_weather.R` to fetch the latest daily climate data from the **DWD (CDC)**.
3.  **Incremental Update:** The script identifies the last entry in `weather_data_full.rds` and only appends new data to prevent duplicates and preserve history.
4.  **Auto-Deploy:** Once the data is updated, the system automatically pushes the new database and the app to **shinyapps.io**.

## 📁 Project Structure
* **`.github/workflows/daily_update.yml`**: The automation logic and CRON schedule.
* **`update_weather.R`**: The core data engine, station mapping, and GDD calculation script.
* **`/Bro_web_app`**: The live application folder.
    * `app.R`: Shiny dashboard UI and server logic.
    * `weather_data_full.rds`: The master weather database (Binary R format).

## 📊 Key Metrics Tracked
* **Temperatures:** Daily Max ($T_{max}$), Min ($T_{min}$), and Mean ($T_m$).
* **GDD (Base 5.6°C):** Calculated as $\max(T_m - 5.6, 0)$ to monitor crop phenology.
* **Frost Events:** Automatic tracking of days where $T_{min} < 0°C$.
* **Precipitation:** Daily rainfall accumulation ($RR$).

## 🛠️ Tech Stack
* **Language:** R (tidyverse, rdwd, shiny, plotly, geosphere)
* **Automation:** GitHub Actions
* **Hosting:** shinyapps.io
* **Data Source:** Deutscher Wetterdienst (DWD) - CDC

---
*Developed for BRO Orchards Decision Support System. Manual Version 1.0 (April 2026).*
