library(rdwd)
library(dplyr)
library(lubridate)
library(purrr)
library(tidyr)

# 1. LOAD EXISTING DATA
file_path <- "Bro_web_app/weather_data_full.rds"
if (file.exists(file_path)) {
  old_data <- readRDS(file_path)
} else {
  stop("Initial data not found. Please upload the first version manually.")
}

# 2. IDENTIFY STATIONS & FETCH RECENT ONLY
# We only get 'recent' (last ~500 days) to keep it fast
ids <- unique(old_data$STATIONS_ID)
recent_files <- selectDWD(id = ids, res = "daily", var = "kl", per = "recent")
raw_data_list <- dataDWD(recent_files, read = TRUE)
new_raw <- bind_rows(raw_data_list) %>% as_tibble()

# 3. CLEAN & PREPARE NEW DATA
processed_new <- new_raw %>%
  mutate(STATIONS_ID = as.character(STATIONS_ID),
         date = as.Date(MESS_DATUM)) %>%
  mutate(across(c(RSK, TMK, TXK, TNK, TGK), ~if_else(.x == -999, NA_real_, .x))) %>%
  # Filter only for dates NOT already in our old_data to avoid duplicates
  filter(date > max(old_data$date, na.rm = TRUE))

# 4. IF NEW DATA EXISTS, MERGE
if (nrow(processed_new) > 0) {
  # Get orchard mapping from old_data (to keep coordinates/names)
  mapping <- old_data %>%
    select(orchards_name, station_name, STATIONS_ID, lat_orchard, lon_orchard, lat_station, lon_station) %>%
    distinct(STATIONS_ID, .keep_all = TRUE)

  final_update <- processed_new %>%
    left_join(mapping, by = "STATIONS_ID") %>%
    select(
      orchards_name, station_name, STATIONS_ID, date,
      lat_orchard, lon_orchard, lat_station, lon_station,
      TG = TGK, TN = TNK, TX = TXK, TM = TMK, RR = RSK
    ) %>%
    mutate(
      year = year(date), month = month(date),
      month_name = as.character(month(date, label = TRUE, abbr = FALSE)),
      day = day(date), frost_day = TN < 0,
      gdd_base5.6 = pmax(TM - 5.6, 0)
    )

  # Combine and Save
  updated_full_data <- bind_rows(old_data, final_update) %>%
    arrange(orchards_name, date)

  saveRDS(updated_full_data, file_path)
  print(paste("Added", nrow(final_update), "new records."))
} else {
  print("No new data found today.")
}
