#load packages
library("readxl")
library("tidyverse")
library("vegan")
library("ggvegan")
#devtools::install_github("Between-the-Fjords/dataDownloader")
library("dataDownloader")

pn <- . %>% print(n = Inf)

# Download OSF
#Download files from OSF
get_file(node = "f3knq",
         file = "biomass2015.xls",
         path = "biomass/data",
         remote_path = "RawData")
get_file(node = "f3knq",
         file = "biomass_taxonomic_corrections.csv",
         path = "biomass/data",
         remote_path = "RawData")

#read excel file
Biomass <- plyr::ldply(1:4, read_excel, path = "biomass/data/biomass2015.xls")
names(Biomass) <- make.names(names(Biomass))


# There are duplicate species in the data set. Those are species that were thought to be different species, but turned out to be the same.

# Sum biomass and cover for duplicate species
BiomassCover <- Biomass %>% 
  mutate(
    site = factor(site, levels = c("H", "A", "M", "L")),
    species = trimws(species)
    ) %>% 
  rename(biomass = production) %>% 
  select(site, plot, species, cover, biomass) %>% 
  group_by(site, plot, species) %>% 
  summarize(biomass = sum(biomass), cover = sum(cover))

# Gather heights and calculate average height including duplicate species
Height <- Biomass %>% 
  mutate(
    site = factor(site, levels = c("H", "A", "M", "L")),
    species = trimws(species)
  ) %>% 
  select(site, plot, species, matches("^H\\d+$")) %>% 
  gather(key = individual, value = height, -site, -plot, -species) %>% 
  group_by(site, plot, species) %>% 
  filter(!is.na(height)) %>% 
  summarise(height = mean(height), n = n())
  
# Merge BiomassCover and Height
biomass <- BiomassCover %>% 
  left_join(Height, by = c("site", "plot", "species"))


# split authority from name
spNames <- strsplit(biomass$species, " ")
nameAuthority <- plyr::ldply(spNames, function(x){
  if(any(grepl("var.", x, fixed = TRUE))){
    speciesName <- paste(x[1:4], collapse = " ")
    authority <- paste(x[-(1:4)], collapse = " ")
  } else {
    speciesName <- paste(x[1:min(length(x), 2)], collapse = " ")  
    authority <- paste(x[-(1:2)], collapse = " ")
  }
  if(is.na(authority)) authority <- ""
  tibble(speciesName, authority)
})

#
getGenus <- function(x) {
  x <- strsplit(x, " ")
  unlist(lapply(x, "[[", 1))
}

# cbind to biomass data
biomass <- biomass %>% 
  bind_cols(nameAuthority) %>%
  select(-species) %>%
  mutate(
    speciesName = gsub("_", " ", speciesName),
    speciesName = gsub("\\.sp", " sp", speciesName),
    speciesName = gsub("\\.gra", " gra", speciesName),
    speciesName = stringi::stri_trans_totitle(speciesName, type= "sentence")
 ) %>%
  mutate(genus = getGenus(speciesName))

#import trait taxonomy dictionary
biomass_taxa <- read_delim("biomass/data/biomass_taxonomic_corrections.csv", delim = ",", comment = "#")

biomass <- biomass %>%
  mutate(speciesName = plyr::mapvalues(speciesName, from = biomass_taxa$wrongName, to = biomass_taxa$correctName, warn_missing = FALSE)) %>% 
  group_by(site, plot)
          
#get family
biomass <- biomass %>% mutate(family = tpl::tpl.get(genus)$family)
#write_csv(biomass, path = "biomass/China_2016_Biomass_cleanded.csv")
                 


# Check the data
##sum unknows
biomass %>% filter(genus == "Unkown") %>% group_by(site, plot, speciesName) %>% summarise(biomass = sum(biomass)) %>% arrange(desc(biomass)) %>% pn

biomass %>% filter(genus == "Unkown") %>% select(speciesName, site, plot, biomass) %>% arrange(desc(biomass)) 




# make plots
ggplot(biomass, aes(x = cover, y = biomass, color = speciesName)) +
  geom_point(show.legend = FALSE) +
  facet_wrap(~ site)

ggplot(biomass, aes(x = height, y = biomass, color = speciesName)) +
  geom_point(show.legend = FALSE) +
  facet_wrap(~ site)


# test biomass along gradient
# summarize biomass per plot and calculate mean per site
sumBiomass <- biomass %>% 
  group_by(plot, site) %>% 
  summarise(n = n(), sumBiomass = sum(biomass, na.rm = TRUE), meanHeight = mean(height, na.rm = TRUE))

fitB <- lm(sumBiomass ~ site, data = sumBiomass)
anova(fitB)
summary(fitB)
plot(fitB)

fitH <- lm(meanHeight ~ site, data = sumBiomass)
anova(fitH)
summary(fitH)
plot(fitH)

# get 
sumBiomass %>% 
  group_by(site) %>% 
  summarise(n = n(), Biomass = mean(sumBiomass, na.rm = TRUE), seB = sd(sumBiomass)/sqrt(n), Height = mean(meanHeight, na.rm = TRUE), seH = sd(meanHeight)/sqrt(n))




#get taxonomy table
con2 <- src_sqlite(path = "community/data/transplant.sqlite", create = FALSE)# need to move all code to dplyr for consistancy

taxa <- tbl(con2, "taxon") %>%
  collect()


setdiff(biomass$speciesName, taxa$speciesName)
# 61 out of 123 species not in common with community data


## biomass by site
biomass %>% 
  summarise(totalBiomass = sum(biomass, na.rm = TRUE)) %>%
  ggplot(aes(x = site, y = totalBiomass)) + 
  geom_boxplot()

biomass %>% 
  group_by(site, genus) %>% 
  summarise(sppSum = sum(biomass, na.rm = TRUE)) %>% 
  arrange(sppSum) %>% 
  ggplot(aes(x = site, y = sppSum, fill = genus)) + 
  geom_bar(stat = "identity", position = "stack", show.legend = FALSE)

#cover by site
biomass %>% 
  summarise(sumCover = sum(cover, na.rm = TRUE)) %>%
  ggplot(aes(x = site, y = sumCover)) + 
  geom_boxplot()

#richness by site
biomass %>% 
  summarise(n = n()) %>%
  ggplot(aes(x = site, y = n)) + 
  geom_boxplot()


## ordinations
biomass_fat <- biomass %>% 
  group_by(speciesName) %>% 
  mutate(biomass = if_else(is.na(biomass), median(biomass, na.rm = TRUE), biomass)) %>%#fill missing values with ?species? median
  group_by(site, plot, speciesName) %>%
  summarise(biomass = sum(biomass)) %>% 
  filter(n() > 3) %>% 
  ungroup() %>%
#  select(-cover, -matches("^H\\d+$"), mean_height, authority) %>%
  spread(key = speciesName, value = biomass, fill = 0)

NMDS <- metaMDS(select(biomass_fat, -(site:plot)) >0)

fNMDS <- fortify(NMDS) %>% filter(Score == "sites") %>% bind_cols(select(biomass_fat, site))

treat_colours <- c("black", "grey50", "red", "green")

g <-ggplot(fNMDS, aes(x = Dim1, y = Dim2, shape = site)) +
  geom_point(fill = "black") +
  coord_fixed(ratio = 1) +
  scale_shape_manual(values = c(24, 22, 23, 25)) +
  guides(shape = guide_legend(override.aes = list(fill = "black"))) +
  labs(x = "NMDS 1", y = "NMDS 2")
g




### SOC from gradient
soc <- read_excel(path = "biomass/data/SOC_Transplant.xlsx", skip = 2)
soc <- soc %>% 
  fill(replicate, elevation)

ggplot(soc, aes(x = elevation, y = `TOC(%)`, color = as.factor(`depth(cm)`))) +
  geom_point(size = 2) +
  facet_grid(~ `depth(cm)`)
