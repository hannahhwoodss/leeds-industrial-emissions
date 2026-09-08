install.packages(c("readxl", "dplyr", "janitor", "sf", "ggplot2"))

library(readxl)
library(dplyr)
library(janitor)
library(sf)
library(ggplot2)

# 2. skip = 9 ignores the top of the Excel files
# and starts reading from the row with real column headers.
pi_2020 <- read_excel("2020 Pollution Inventory Dataset v2.xlsx", skip = 9) %>%
  clean_names()

pi_2024 <- read_excel("2024 Pollution Inventory Dataset.xlsx", skip = 9) %>%
  clean_names()

# 3. Filter to Leeds only ----
pi_2020_leeds <- pi_2020 %>%
  filter(grepl("Leeds", site_address, ignore.case = TRUE))

pi_2024_leeds <- pi_2024 %>%
  filter(grepl("Leeds", site_address, ignore.case = TRUE))

# 4. Fix the emissions column so it loads as numbers, not text 
pi_2020_leeds <- pi_2020_leeds %>%
  mutate(quantity_released_kg = as.numeric(quantity_released_kg))

pi_2024_leeds <- pi_2024_leeds %>%
  mutate(quantity_released_kg = as.numeric(quantity_released_kg))

# 5. Total emissions per company, per year
totals_2020 <- pi_2020_leeds %>%
  group_by(operator_name) %>%
  summarise(total_kg_2020 = sum(quantity_released_kg, na.rm = TRUE))

totals_2024 <- pi_2024_leeds %>%
  group_by(operator_name) %>%
  summarise(total_kg_2024 = sum(quantity_released_kg, na.rm = TRUE))

# 6. Join both years together and calculate % change
comparison <- full_join(totals_2020, totals_2024, by = "operator_name") %>%
  mutate(pct_change = (total_kg_2024 - total_kg_2020) / total_kg_2020 * 100)

# 7. Add site locations (easting/northing)
locations <- pi_2020_leeds %>%
  distinct(operator_name, easting, northing)

comparison_mapped <- comparison %>%
  left_join(locations, by = "operator_name")

# 8. Convert to spatial points 
comparison_sf <- comparison_mapped %>%
  filter(!is.na(easting), !is.na(northing)) %>%
  st_as_sf(coords = c("easting", "northing"), crs = 27700)

# 9. Leeds boundary outline from ONS ----
leeds_boundary_url <- "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Local_Authority_Districts_December_2024_Boundaries_UK_BGC/FeatureServer/0/query?where=LAD24NM='Leeds'&outFields=*&f=geojson"

leeds_boundary <- st_read(leeds_boundary_url)

# 10. Build the final map 
ggplot() +
  geom_sf(data = leeds_boundary, fill = "grey95", color = "black") +
  geom_sf(data = comparison_sf, aes(color = pct_change, size = total_kg_2024), alpha = 0.85) +
  scale_color_gradient2(
    low = "blue", mid = "grey70", high = "red",
    midpoint = 0, name = "% change\n2020–2024"
  ) +
  labs(
    title = "Change in reported industrial emissions, Leeds (2020–2024)",
    subtitle = "Point size = total emissions in 2024 (kg)",
    size = "2024 total (kg)"
  ) +
  theme_minimal() +
  theme(axis.text = element_blank(), axis.ticks = element_blank())

ggsave("leeds_emissions_map.png", width = 8, height = 6, dpi = 300)




