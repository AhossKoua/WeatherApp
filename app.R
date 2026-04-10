# This is a Shiny web application to visualize weather data (updated V.0.0.1)

# 0. LOAD LIBRARIES -------------------------------------------------------
library(shiny)
library(bslib)
library(tidyverse)
library(plotly)
library(leaflet)
library(bsicons)
library(lubridate)

# 1. LOAD THE PREPARED DATA -----------------------------------------------
# Ensure your RDS file has columns: TX (Max), TN (Min), TM (Mean), RR (Rain), gdd_base5
joined_data <- readRDS("weather_data_full.rds")

# 2. UI - USER INTERFACE --------------------------------------------------
ui <- page_navbar(
  title = "BRO Orchards Decision Support System",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  
  sidebar = sidebar(
    title = "Analysis Controls",
    selectInput("orchard_select", "Choose Orchard:", choices = NULL),
    dateRangeInput("date_range", "Time Period:", 
                   start = "2025-01-01", end = Sys.Date()),
    
    hr(),
    # Bio-fix for Breeding Phenology
    dateInput("biofix_date", "Bio-fix Date (e.g. Flowering):", value = "2025-03-01"),
    helpText("GDD & Chilling Hours are calculated from this date forward."),
    
    hr(),
    checkboxInput("show_frost_line", "Show 0°C Frost Line", value = TRUE)
  ),
  
  nav_panel(
    title = "Analysis Dashboard",
    
    # --- Inside nav_panel("Analysis Dashboard", ...) ---
    
    # ROW 1: All KPIs (Top Row)
    layout_column_wrap(
      width = 1/5, # Set to 1/5 to fit 5 boxes in one line
      fill = FALSE,
      
      # Existing Frost Box
      value_box(
        title = "Frost Events",
        value = textOutput("frost_count"),
        showcase = bsicons::bs_icon("thermometer-snow"),
        theme = "danger"
      ),
      
      # KPI Box 2: Total Water
      value_box(
        title = "Total Accum. Rain",
        value = textOutput("total_rain"),
        showcase = bsicons::bs_icon("droplet-fill"),
        theme = "primary"
      ),
      
      # KPI Box 3: Growth Progress
      value_box(
        title = "GDD (Base 5.6°C)",
        value = textOutput("gdd_sum"),
        showcase = bsicons::bs_icon("flower1"),
        theme = "success"
      ),
      
      # NEW: Heat Days Box
      value_box(
        title = "Heat Days (≥30°C)",
        value = textOutput("heat_days"),
        showcase = bsicons::bs_icon("sun-fill"),
        theme = "warning"
      ),
      
      # NEW: Temperature Extremes (Small Box)
      value_box(
        title = "Temp Extremes",
        value = htmlOutput("temp_extremes_small"),
        showcase = bsicons::bs_icon("exclamation-triangle"),
        theme = "secondary"
      )
    ),
    
    # ROW 2: Both Graphs Side-by-Side
    layout_column_wrap(
      width = 1/2, # Split 50/50
      card(
        full_screen = TRUE,
        card_header("Climatic Overview (Rain & Avg Temp)"),
        plotlyOutput("climate_combined_plot")
      ),
      card(
        full_screen = TRUE,
        card_header("Temperature Trends (Max/Min)"),
        plotlyOutput("temp_plot")
      )
    ),
    
    # ROW 3: Location Context (Full Width at Bottom)
    card(
      card_header("Location Context"),
      leafletOutput("map", height = "350px")
    )
  )
)

# 3. SERVER - THE LOGIC ---------------------------------------------------
server <- function(input, output, session) {
  
  observe({
    updateSelectInput(session, "orchard_select", 
                      choices = unique(joined_data$orchards_name))
  })
  
  filtered_data <- reactive({
    req(input$orchard_select)
    joined_data %>%
      filter(
        orchards_name == input$orchard_select,
        date >= input$date_range[1],
        date <= input$date_range[2]
      )
  })
  
  # --- KPI CALCULATIONS ---
  
  output$frost_count <- renderText({ 
    paste(sum(filtered_data()$TN < 0, na.rm = TRUE), "Days") 
  })
  
  output$heat_days <- renderText({
    paste(sum(filtered_data()$TX >= 30, na.rm = TRUE), "Days")
  })
  
  output$chill_hours <- renderText({
    # Simple model: Hours where temp is between 0 and 7.2°C 
    # (Approximated from daily Mean TM if hourly data isn't available)
    df_bio <- filtered_data() %>% filter(date >= input$biofix_date)
    chill_days <- sum(df_bio$TM > 0 & df_bio$TM <= 7.2, na.rm = TRUE)
    paste(chill_days * 24, "Hrs (Est.)")
  })
  
  output$gdd_sum <- renderText({
    df_bio <- filtered_data() %>% filter(date >= input$biofix_date)
    paste(round(sum(df_bio$gdd_base5, na.rm = TRUE), 0), "Units")
  })
  
  output$rain_intensity <- renderText({
    max_rain <- max(filtered_data()$RR, na.rm = TRUE)
    paste0(max_rain, " mm in 24h")
  })
  
  output$temp_extremes <- renderUI({
    df <- filtered_data()
    max_row <- df[which.max(df$TX), ]
    min_row <- df[which.min(df$TN), ]
    HTML(paste0(
      "<b>Highest:</b> ", max_row$TX, "°C on ", max_row$date, "<br/>",
      "<b>Lowest:</b> ", min_row$TN, "°C on ", min_row$date
    ))
  })
  
  output$total_rain  <- renderText({ 
    paste(round(sum(filtered_data()$RR, na.rm = TRUE), 1), "mm") 
  })
  
  
  # --- PLOTS ---
  
  
  output$climate_combined_plot <- renderPlotly({
    df <- filtered_data()
    monthly_df <- df %>%
      mutate(month = floor_date(date, "month")) %>%
      group_by(month) %>%
      summarise(precip = sum(RR, na.rm = TRUE), temp_avg = mean(TM, na.rm = TRUE))
    
    coeff <- max(monthly_df$precip, na.rm = TRUE) / max(monthly_df$temp_avg, na.rm = TRUE)
    
    # THE GATEKEEPER: Stop here if there is no data
    # This prevents the "Argument 1 ist kein Vektor" error
    validate(
      need(nrow(df) > 0, "No data found for this orchard and date range. Please check your filters.")
    )
    
    p <- ggplot(monthly_df, aes(x = month)) +
      geom_col(aes(y = precip, fill = "Rainfall")) +
      geom_line(aes(y = temp_avg * coeff, color = "Avg Temp"), linewidth = 1) +
      scale_y_continuous(name = "Rain (mm)", sec.axis = sec_axis(~./coeff, name = "Temp (°C)")) +
      scale_fill_manual(values = "#3498db") +
      scale_color_manual(values = "#e74c3c") +
      theme_minimal() + labs(x = "Date")
    
    ggplotly(p) 
  })
  
  
  output$temp_plot <- renderPlotly({
    df <- filtered_data() # After you call the data to be visualized, then you call the Gate keeper before ploting.
    
    # THE GATEKEEPER: Stop here if there is no data
    # This prevents the "Argument 1 ist kein Vektor" error
    validate(
      need(nrow(df) > 0, "No data found for this orchard and date range. Please check your filters.")
    )
    
    p <- ggplot(df, aes(x = date)) +
      geom_line(aes(y = TX, color = "Max"), linewidth = 0.7) +
      geom_line(aes(y = TN, color = "Min"), linewidth = 0.7) +
      scale_color_manual(values = c("Max" = "#cc0000", "Min" = "#0066cc")) +
      theme_minimal() + labs(y = "Temperature °C", x = "Date")
    if(input$show_frost_line) p <- p + geom_hline(yintercept = 0, linetype = "dashed")
    ggplotly(p)
  })
  
  output$map <- renderLeaflet({
    req(nrow(filtered_data()) > 0)
    row <- filtered_data()[1, ]
    leaflet() %>%
      addTiles() %>%
      addMarkers(lng = row$lon_orchard, lat = row$lat_orchard, popup = "Orchard") %>%
      addCircleMarkers(lng = row$lon_station, lat = row$lat_station, color = "red")
  })
  
  # --- Inside the Server Function ---
  
  # Simplified Extremes for the Value Box
  output$temp_extremes_small <- renderUI({
    df <- filtered_data()
    req(nrow(df) > 0)
    
    max_val <- max(df$TX, na.rm = TRUE)
    min_val <- min(df$TN, na.rm = TRUE)
    
    # Using small font to ensure it fits the box nicely
    HTML(paste0(
      "<span style='font-size: 0.8em;'>↑ <b>", max_val, "°C</b></span><br/>",
      "<span style='font-size: 0.8em;'>↓ <b>", min_val, "°C</b></span>"
    ))
  })
  
  # Ensure GDD uses your specific base 5.6°C
  output$gdd_sum <- renderText({ 
    df_bio <- filtered_data() %>% filter(date >= input$biofix_date)
    # Assuming your data has a column or you calculate it here:
    gdd_vals <- pmax(df_bio$TM - 5.6, 0)
    paste(round(sum(gdd_vals, na.rm = TRUE), 0), "Units")
  })
}

# 4. START THE APP --------------------------------------------------------
shinyApp(ui, server)
