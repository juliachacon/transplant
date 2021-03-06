#load packages
library("tidyr")
library("plyr")
library("DBI")# also needs RMySQL installed
library("dplyr")
library("ggplot2")

#source functions
source("community/R/load_subturfcomm.R")
source("community/R/load_comm.R")

#make database connection
con <- dbConnect(RMySQL::MySQL(), group = "transplant")


#load cover data and metadata
subturf_thin <- load_subturfcomm(con = con)
#  spread(subturf.thin, key = "subTurf", value = "adult", fill = 0)
cover_thin <-load_comm(con = con)

##missing turfs
subturf_thin %>% 
  group_by(turfID, year, originSiteID, destSiteID, TTtreat) %>%
  summarise(n = "") %>% 
  spread(key = year, value = n, fill = "miss") %>%
  ungroup() %>%
  filter(drop = rowSums(. == "miss") > 0) %>%
  select(-originSiteID)

write.table(.Last.value, file = "missingTurfs.dat", sep = "\t", quote = FALSE, row.names = FALSE)

#check subturf and cover contain same species
subturf_freq <- subturf_thin %>% 
  group_by(turfID, species, year) %>%
  summarise(n = n())

#merge cover and subturf
mergedCoverFreq <- merge(cover_thin, subturf_freq, all = TRUE)

mergedCoverFreq %>% filter(is.na(cover)) %>% select(turfID, year, species, n)

mergedCoverFreq %>% filter(is.na(n)) %>% select(turfID, year, species, cover)

#subturf stability

subturfChange <- function(dat, turfID, start, end){
  #extract turf & years
  subturf <- dat[dat$turfID == turfID & (dat$year == start | dat$year == end), ] 
  
  #check bothyears present
  if(!all(c(start, end) %in% subturf$year)){
    warning("no data found for one year in ", turfID)
    return()
  }
  subturf <- spread(subturf, key = year, value = adult, fill = 0)
  
  subturf$change <- "absent"
  
  #find s & e = persistence
  subturf$change[subturf[, as.character(start)] & subturf[, as.character(end)]] <- "persist"
  # s & !e = extinction
  subturf$change[subturf[, as.character(start)] & !subturf[, as.character(end)]] <- "extinct"  
  # !s & e = recruitment
  subturf$change[!subturf[, as.character(start)] & subturf[, as.character(end)]] <- "recruit"  
    
  subturf$x <- (subturf$subTurf - 1) %% 5 + 1
  subturf$y <- (subturf$subTurf - 1) %/% 5 + 1

  ggplot(subturf, aes(x = x, y = y, fill = change)) + 
    geom_raster() +
    facet_wrap(~species) +
    labs(title = paste(turfID, start, "-", end), x = NULL, y = NULL)
}

subturfChange(dat = subturf_thin, turfID = "L1-C", start = 2012, end = 2013)

sapply(unique(subturf_thin$turfID[subturf_thin$TTtreat == "control"]), function(turfID) {
  x11()  
  print(turfID)
  g <- subturfChange(subturf_thin, turfID = turfID, start = 2012, end = 2013)
  print(g)
  NULL
  })

sapply(unique(subturf_thin$turfID[subturf_thin$TTtreat == "local"]), function(turfID) {
  x11()  
  print(turfID)
  g <- subturfChange(subturf_thin, turfID = turfID, start = 2012, end = 2013)
  print(g)
  NULL
})


#richness patterns across years
cover_thin %>% group_by(destSiteID, TTtreat, turfID, year) %>%
  summarise(richness = n()) %>%
  ggplot(aes(x = destSiteID, y = richness, fill = as.factor(year))) +
    geom_boxplot()+
    facet_wrap(~TTtreat) +
    labs(x = "Destination Site", y = "Turf Richness", fill = "Year")
ggsave("RichnessPatterns.png", width = 10)

cover_thin %>% group_by(destSiteID,originSiteID, TTtreat, turfID, year) %>%
  summarise(richness = n()) %>%
  ggplot(aes(x = year, y = richness, colour = factor(turfID, levels = sample(unique(turfID))))) +
  geom_line(show.legend = FALSE) +
  facet_grid(originSiteID~TTtreat) +
  labs(x = "Origin Site", y = "Turf Richness", fill = "Year")
ggsave("RichnessPatterns2.png", width = 10)

#persistence, recruitment and loss

##large changes in cover
changes <- cover_thin %>% 
  select(originSiteID, turfID, destSiteID, TTtreat, year, species, cover, speciesName) %>%
  filter(TTtreat %in% c("control", "local")) %>% 
  spread(key = year, value = cover, fill = 0) %>%
  gather(key = year, value = cover, -originSiteID, -turfID, -destSiteID, -TTtreat, -species, -speciesName) %>%
  group_by(turfID, species) %>%
  mutate(RANGE = diff(range(cover))) %>%
  spread(key = year, value = cover)

ggplot(changes, aes(x = RANGE)) + geom_histogram() + facet_wrap(~originSiteID)

changes %>% ungroup() %>% filter(RANGE >= 25) %>% arrange(turfID) %>% select(-originSiteID, -destSiteID, -RANGE, -species) %>% as.data.frame()

## sum of covers
cover_thin %>% 
  group_by(turfID, year, TTtreat, destSiteID, originSiteID) %>% 
  summarise(sumCover = sum(cover)) %>%
  ungroup() %>%
  arrange(desc(sumCover))
  
  cover_thin %>% 
  group_by(turfID, year, TTtreat, destSiteID, originSiteID) %>% 
  summarise(sumCover = sum(cover)) %>%
  ggplot(aes(x = year, y = sumCover, colour = factor(turfID, levels = sample(unique(turfID))))) +
  geom_line(show.legend = FALSE) +
  scale_x_continuous(breaks = unique(cover_thin$year), labels = paste0("`",substr(unique(cover_thin$year), 3, 4))) +
  facet_grid(originSiteID~TTtreat) +
  labs(x = "Year", y = "Sum of Covers")
ggsave("cover.png", width = 10)

#species dropouts  - not working properly
cover_thin %>% filter(TTtreat %in% c("local", "control")) %>% group_by(species, year) %>% summarise(n = n()) %>% spread(key = year, value = n, fill = 0) %>% ungroup() %>% mutate(max = apply(.[,-1], 1, max), min = apply(.[,-1], 1, min), variability = (max - min)/(max + 10)) %>% arrange(desc(variability)) %>% select(-max, -min, - variability) %>% head(30)


## persist, recruit, expirate, (recover)
#markov matrix ? species & climate specific parameters.

#plot n subturf * species over different years. Correlation. effect of site?
#overlap - % year t + 1 occupied in year t? effect of n plots? Null model expectation?

subturfYear <- subturf_thin %>% 
  filter(TTtreat %in% c("local", "control")) %>%
  select(turfID, subTurf, year, species, adult, TTtreat) %>%
  spread(key = year, value = adult, fill = 0)

findPersistance <-function(dat){
  years <- names(dat)[names(dat) %in% 2000:3000]
  years <- as.numeric(years)
  ldply(min(years):max(years), function(y1){
    ldply(y1:max(years), function(y2){
      res <- apply(dat[, as.character(y1:y2), drop = FALSE] == 1, 1, all)
      c(start = y1, end = y2, persist = sum(res))
    })
  })
}
persist <- findPersistance(subturfYear)

ggplot(persist, aes(x = end, y = persist, colour = as.factor(start))) + 
  geom_line() + 
  geom_point(aes( size = ifelse(start == end, 1, NA)), show.legend = FALSE) +
  scale_y_continuous(limits = c(0, NA))

#NULL model
#1 reassign species to subplots
#3 calculate persistance
#4 repeat and find 95% ci
NullPersistence <- replicate(100, {
  subturfYearP <- subturf_thin %>% 
    filter(TTtreat %in% c("local", "control")) %>%
    select(turfID, subTurf, year, species, adult, TTtreat) %>%
    group_by(turfID, year, species, TTtreat) %>%
    mutate(subTurf = sample(1:25, size = n(), replace = FALSE)) %>%
    spread(key = year, value = adult, fill = 0)
  findPersistance(subturfYearP)$persist
})
NullPersistence <- t(apply(NullPersistence, 1, quantile, prob = c(0.025, 0.5, 0.975)))

persist <- cbind(persist, NullPersistence)

persist %>% gather(key = "key", value = "value", -start, -end) %>% 
  ggplot(aes(x = end, y = value, colour = as.factor(start), linetype = key)) + 
    geom_line() + 
    geom_point(aes( size = ifelse(start == end, 1, NA)), show.legend = FALSE) +
    scale_y_continuous(limits = c(0, NA))+
    scale_linetype_manual(limits = c("persist", "97.5%", "50%", "2.5%"), values = c("solid", "dotted", "dashed", "dotted"))


##########
#year on year distances

yearOnYearDist <- function(dat) {
    ddply(dat, .(turfID, TTtreat, originSiteID), function(x) {
      years <- sort(unique(x$year))
      years <- years[1:(length(years) - 1)]
      ldply(years, function(y) {
        x <- x[x$year %in% c(y, y + 1),]
        if (NROW(x) != 2)
          bray = NA
        else
          bray = vegan::vegdist(x[,-(1:which(names(x) == "year"))])
        data.frame(year = y, bray = unclass(bray))
      })
    })
}

controlDists <- cover_thin %>% 
  filter(TTtreat %in% c("control", "local")) %>%
  select(-speciesName) %>%
  spread(key = species, value = cover, fill = 0) %>%
  yearOnYearDist()

ggplot(controlDists, aes(x = originSiteID, y = bray)) + geom_boxplot()
ggplot(controlDists, aes(x = 1, y = bray)) + geom_boxplot() + geom_rug()

allDists <- cover_thin %>% 
  select(-speciesName) %>%
  spread(key = species, value = cover, fill = 0) %>%
  yearOnYearDist()

ggplot(allDists, aes(x = TTtreat, y = bray)) + geom_boxplot()
ggplot(allDists, aes(x = TTtreat, y = bray, fill = as.factor(year))) + geom_boxplot() 
