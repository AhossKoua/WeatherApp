🍎 Orchard Climate Monitor (Automated)
An automated data pipeline and Shiny Decision Support System that tracks weather conditions, Growing Degree Days (GDD), and frost events for specific orchard locations using German Weather Service (DWD) data.
🚀 How it Works
This project is fully automated using GitHub Actions. You don't need to run any code manually to keep the data fresh.
1.	Daily Trigger: Every morning at 04:00 UTC, a GitHub "Robot" wakes up.
2.	Data Pull: The robot runs an R script (update_weather.R) that fetches the latest daily climate data from the DWD (CDC).
3.	Incremental Update: The system identifies the latest date in the existing database and only appends new rows to prevent data loss or duplicates.
4.	Auto-Deploy: The updated database is saved to this repository and immediately pushed to shinyapps.io, ensuring the live web app is always current.
📁 Project Structure
•	update_weather.R: The core data engine and spatial mapping script.
•	/Bro_web_app: Contains the live application.
o	app.R: The Shiny dashboard code.
o	weather_data_full.rds: The master weather database (updated daily).
•	.github/workflows/daily_update.yml: The automation logic and schedule.
📊 Key Metrics Tracked
•	Daily Temperatures: Max ($T_{max}$), Min ($T_{min}$), and Mean ($T_m$).
•	GDD (Base 5.6°C): Calculated as $\max(T_m - 5.6, 0)$ to track phenological development.
•	Frost Events: Automatic detection of days where $T_{min} < 0$.
•	Precipitation: Daily rainfall accumulation.
🛠️ Tech Stack
•	Language: R (tidyverse, rdwd, shiny, plotly)
•	Automation: GitHub Actions
•	Hosting: shinyapps.io
•	Data Source: Deutscher Wetterdienst (DWD)
________________________________________
Developed for BRO Orchards Decision Support. Updated: April 2026.
