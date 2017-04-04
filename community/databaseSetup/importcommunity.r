####################
#todo############
#check species in taxon table before inserting
#merge subturf taxa
####################

import.data<-function(dat, mergedictionary){#dat is data.frame from the correctly formatted csv file loaded into R
  require("assertthat")

    dat <- dat[!is.na(dat$originPlotID),]
    head(dat)
    names(dat)

  print(max(nchar(as.character(dat$comment)))) #how long is longest comment)
    
    #extract turf data
    turf <- dat[,c("turfID", "TTtreat", "originPlotID", "destinationPlotID")]
    turf <- unique(turf)
    turf$TTtreat <- trimws(turf$TTtreat) #  trim white spaces
  
    turf
    names(turf)
    
    alreadyIn <- dbGetQuery(con,"select turfID from turfs")$turfID
    newTurfs <- turf[!as.character(turf$turfID) %in% alreadyIn,] #find which turfs IDs are not already in database
    
    if(nrow(newTurfs) > 0) {
      dbPadWriteTable(con, "turfs", newTurfs)
    }
    nrow(turf)
    nrow(newTurfs)
    
    message("done turfs")                                  
    
    #subTurf env
    subturfEnv <- dat %>% 
      filter(Measure != "cover%") %>% 
      select(turfID, subPlot, year, moss, lichen, litter, soil, rock, comment) %>%
      rename(subTurf = subPlot) %>%
      mutate(subTurf = as.numeric(subTurf)) %>%
      filter(is.na(comment) | comment != "correction")
            
    assert_that(all(dat$turfID %in% subturfEnv$turfID))
             
      if(!is.null(dat$missing)){
         bad = dat$missing[dat$Measure != "cover%"]
         bad[is.na(bad)] <- ""
        subturfEnv$bad <- bad
      } else{
        subturfEnv$bad <-  ""    
      }
    subturfEnv 
    dbPadWriteTable(con, "subTurfEnvironment", subturfEnv)
    nrow(subturfEnv)
    
    #TurfEnv    
    turfEnv <- dat %>% 
    filter(Measure == "cover%") %>% 
      select(turfID, year, moss, lichen, litter, soil, rock, totalVascular, totalBryophytes, totalLichen, vegetationHeight, mossHeight, litterThickness, comment, recorder, date) %>%
      filter(is.na(comment) | comment != "correction")

    assert_that(!any(nchar(as.character(turfEnv$comment[!is.na(turfEnv$comment)])) > 255))
    dbPadWriteTable(con, "turfEnvironment", turfEnv)
  nrow(turfEnv)   
  
  #Mergedistionary
#  mergedictionary <- dbGetQuery(con,"SELECT * FROM mergedictionary")  
  
    #TurfCommunity  
  spp <- bind_cols(dat[, c("turfID", "year")], dat[, (which(names(dat) == "recorder") + 1) : (which(names (dat) == "moss")-1) ])[dat$Measure == "cover%",]
  spp[, 3 : ncol(spp)] <- plyr::colwise(as.numeric)(spp[, 3 : ncol(spp)])
  notInMerged <- setdiff(names(spp)[-(1:2)], mergedictionary$oldID)
  mergedictionary <- bind_rows(mergedictionary, data_frame(oldID = notInMerged, newID = notInMerged))
  mergedNames <- plyr::mapvalues(names(spp)[-(1:2)], from = mergedictionary$oldID, to = mergedictionary$newID, warn_missing = FALSE)
  sppX <- lapply(unique(mergedNames), function(n){
    rowSums(spp[, names(spp) == n, drop = FALSE])
    })
  sppX <- as_data_frame(setNames(sppX, unique(mergedNames)))
  spp <- bind_cols(spp[, 1:2], sppX)
    unique(as.vector(sapply(spp[, -(1:2)], as.character)))    #oddity search
    table(as.vector(sapply(spp[, -(1:2)], as.character)), useNA = "ifany") 

  sppT <- plyr::ldply(as.list(3:ncol(spp)),function(nc){
      sp <- spp[, nc]
      cf <- grep("cf", sp, ignore.case = TRUE)
      sp <- gsub("cf", "", sp, ignore.case = TRUE)
      sp <- gsub("\\*", "", sp, ignore.case = TRUE)
      spp2 <- data_frame(turfID = spp$turfID, year = spp$year, species = names(spp)[nc], cover = as.numeric(sp), cf = 0)
      spp2$cf[cf] <- 1
      spp2 <- spp2[!is.na(spp2$cover), ]
      spp2 <- spp2[spp2$cover > 0, ]
      spp2
    })
  initNrowTurfCommunity <- dbGetQuery(con, "select count(*) as n from turfCommunity")
  dbPadWriteTable(con, "turfCommunity", sppT)
  finalNrowTurfCommunity <- dbGetQuery(con, "select count(*) as n from turfCommunity")
  
  #check correct number rows
  assert_that(nrow(sppT) == finalNrowTurfCommunity - initNrowTurfCommunity)

  
  #subTurfCommunity  
  message("subturfcommunity")  
  subspp <- bind_cols(dat[, c("turfID", "year", "subPlot")], dat[, (which(names(dat) == "recorder") + 1) : (which(names(dat) == "moss") -1) ]) %>%
    filter(dat$Measure != "cover%") %>% 
    mutate(subPlot = as.integer(subPlot))
  
  subspp[subspp == 0] <- NA
  subsppX <- lapply(unique(mergedNames), function(sppname){
      species <- subspp[, names(subspp) == sppname]
      if (NCOL(species) == 1) {
        return(species)
      } else {
        apply (species, 1, function(r) {
          occurence <- which(!is.na(r))
          if(length(occurence) == 0) return(NA)
          if(length(occurence) == 1) return(r[occurence])
          else {
            warning(paste("more than one species observation in same subplot!"))
            write.csv(data.frame(filename = n, species = species, occurence = r[occurence]), file = "cooccurence_log.csv", append = TRUE)
            return(r[occurence][1])
          }
        })
      }
    })
    
    
    subsppX <- bind_cols(setNames(subsppX, unique(mergedNames)))
    subspp <- bind_cols(subspp[, 1:3], subsppX)
    print(table(as.vector(sapply(subspp[, -(1:3)], as.character)))) #oddity search
    
    
    #Find oddities in dataset:
    tmp <- sapply(subspp, function(z){a <- which(z == "f"); if(length(a) > 0){subspp[a, 1:3]} else NULL})
    tmp[!sapply(tmp, is.null)]
    spp0 <- plyr::ldply(as.list(4:ncol(subspp)), function(nc){
      sp <- subspp[,nc ]
      spp2 <- data_frame(turfID = subspp$turfID, year = subspp$year, subTurf = subspp$subPlot, species = names(subspp)[nc], seedlings = 0, juvenile = 0, adult = 0, fertile = 0, vegetative = 0, dominant = 0, cf = 0)
      spp2$cf[grep("cf",sp, ignore.case = TRUE)] <- 1
      spp2$fertile[grep("F",sp, ignore.case = FALSE)] <- 1
      spp2$dominant[grep("D",sp, ignore.case = TRUE)] <- 1       
      spp2$vegetative[grep("V",sp, ignore.case = TRUE)] <- 1
      spp2$seedlings[grep("S",sp, ignore.case = TRUE)] <- 1
      for(i in 2:50){
        spp2$seedlings[grep(paste("Sx",i,sep=""), sp, ignore.case = TRUE)] <- i
        spp2$seedlings[grep(paste(i,"xS",sep=""), sp, ignore.case = TRUE)] <- i
      }    
      spp2$juvenile[grep("J", sp, ignore.case = TRUE)] <- 1
      for(i in 2:50){
        spp2$juvenile[grep(paste("Jx", i, sep = ""),sp, ignore.case = TRUE)] <- i
         spp2$juvenile[grep(paste("xJ", i, sep = ""),sp, ignore.case = TRUE)] <- i
      }
      spp2$adult[grep("[F|V|D]", sp, ignore.case = TRUE)] <- 1
      spp2$adult[grep("^\\d+$", sp, ignore.case = TRUE)] <- 1
      spp2<-spp2[rowSums(spp2[,-(1:4)])>0,] #keep only rows with presences
      spp2
    })  
    
    
    #euphrasia rule adults=adults+juvenile+seedling, j=j+s, s=s
    seedlingSp <- c("Euph.fri", "Eup.fri","Eup.sp","Eup.str","Euph.fri","Euph.sp", "Euph.str","Euph.str.1", "Euph.wet", "Poa.ann","Thlaspi..arv","Com.ten","Gen.ten", "Rhi.min", "Cap.bur", "Mel.pra","Mel.sp","Mel.syl","Noc.cae","Ste.med","Thl.arv","Ver.arv")
    #########more annuals?
    
    tmpSp <- spp0[spp0$species %in% seedlingSp,]
      tmpSp$juvenile[tmpSp$juvenile == 0 & tmpSp$adult == 1] <- 1  
      tmpSp$seedlings[tmpSp$seedlings == 0 & tmpSp$adult == 1] <- 1
      tmpSp$seedlings[tmpSp$seedlings == 0 & tmpSp$juvenile == 1] <- 1
    spp0[spp0$species %in% seedlingSp,] <- tmpSp
    
    initNrowSTurfCommunity <- dbGetQuery(con, "select count(*) as n from subTurfCommunity")
    dbPadWriteTable(con, "subTurfCommunity", spp0)
    finalNrowSTurfCommunity <- dbGetQuery(con, "select count(*) as n from subTurfCommunity")
    
    #check correct number rows
    assert_that(nrow(spp0) == finalNrowSTurfCommunity - initNrowSTurfCommunity)

}


# Codes for deleting tables:
wipe <- function(){
  dbGetQuery(con, "Delete FROM subTurfCommunity")                            
  dbGetQuery(con, "Delete FROM subTurfEnvironment")
  dbGetQuery(con, "Delete FROM turfCommunity")
  dbGetQuery(con, "Delete FROM turfEnvironment")
   #dbGetQuery(con, "Delete * FROM turfs")
  message("Database wiped. Hope you really wanted to do that!")
}

 
#replace mytable with a table you want to clean
#duplicate lines as necessary to clean all tables
#delete tables in the correct order or it won't work
#Then just run wipe() to clean the database
