R tutorial China
================

<style>
p.caption {
  font-size: 0.8em;
}
</style>

# TRANSPLANT EXPERIMENT GONGGA MOUNTAIN (CHINA)

## Cover and composition data

script: start\_here.R

This script is going to:

1.  Read the data from the transplants (transplant.sqlite)
2.  Load cover data and metadata (cover\_thin)
3.  Make a fat table (cover) with species names in columns and cover
    values in each plot
4.  Make meta data (cover\_meta) This are the meta data of the “cover”
    tibble
5.  Make turf list (turfs)
6.  Get a taxonomy table, with abreviate and complete species names;
    authority; family and functional group. There is also other columns
    that appear empty.

We can either source it or run it step by step to see what is doing:

``` r
source("community/start_here.R") 
```

Here is the code of start\_here.R in case you want to explore it a bit.

``` r
## ---- sources a few functions that are stored in community/R

fl <- list.files("community/R/", full.names = TRUE)
sapply(fl, source)
path <- "community/"

## ---- load_community

if(!exists("path")) {
  path <- ""
}

# ---- make database connection

con <- src_sqlite(path = paste0(path, "data/transplant.sqlite"), create = FALSE)

# ---- load cover data and metadata
cover_thin <- load_comm(con = con)


# ---- make fat table
cover <- cover_thin %>% 
  select(-speciesName) %>%
  spread(key = species, value = cover, fill = 0)


# ---- make meta data
cover_meta <- cover[, 1:which(names(cover) == "year")]

# ---- make turf list
turfs <- cover_meta[!duplicated(cover_meta$turfID),]

# ---- remove meta from cover
cover <- cover[, -(1:which(names(cover) == "year"))]

#save(cover, cover_meta, cover_thin, file = "cover.RData")

# ---- get taxonomy table

taxa <- tbl(con, "taxon") %>%
  collect()
```

### Exploring how the data are organized

cover\_thin contains community data (not traits yet\!). Specifically,
cover of each species, per turf and treatments.

Explore the columns names in cover\_thin:

``` r
colnames(cover_thin)
```

  - originSiteID
  - originBlockID
  - originPlotID
  - turfID  
  - destPlotID
  - destBlockID
  - destSiteID
  - TTtreat
  - year
  - species
  - cover
  - flag
  - speciesName

cover is a summary of the total cover of each species in cover\_thin:

Explore the columns names in cover:

``` r
colnames(cover)
```

Check the dimensions of cover\_thin and cover:

``` r
dim(cover_thin)
#> [1] 9770   13

dim(cover)
#> [1] 1056  119
```

Explore the levels of each factor, to get an idea of the experimental
setup. For example, number of sites, blocks per site, Treatments names,
and how are the variables stored in cover\_thin.

Just to remember, there are four study sites that contains an in situ
warming experiments using OTCs and reciprocal community transplantation
experiments (i.e., warming and cooling) between all pairs of
neighbouring sites along the gradient.

There are seven blocks at each site. Within each of the seven blocks at
each site, plots were randomly designated to SIX different experimental
treatments:

(OTC)- passive warming with an open top chamber (OTC; they are located
in all sites)

(1)- transplanting to a site one step warmer along the gradient. In this
case, this occurred transplanting the turf to a lower elevation
(warming; from sites High alpine (“H”), Alpine (“A”), Middle alpine
(“M”))

(2)- transplanting to a site one step colder along the gradient. That
means transplanting the turf to a higher elevation (cooling; from sites
Alpine (“A”), Middle alpine (“M”), Lowland (“L”)

(3)- transplanting down the entire gradient (extreme warming; from site
High alpine)

(4)- transplanting up the entire gradient (extreme cooling, from site
Lowland)

(0)- transplanting within blocks (to control for the transplanting
itself)(Local transplant; all sites)

(C)- an untouched control plot (unmanipulated Control; all sites)

Thus, each OTC has a local unmanipulated control, and each transplanted
turf has an “origin” site and a “destination” site, with two types of
controls, local transplant and untouched plots, in each

Now, check all this information in the data set:

Sites:

``` r
levels(cover_thin$originSiteID) 
#> [1] "H" "A" "M" "L"
```

There are seven blockes per elevation/site:

``` r
unique(cover_thin$originBlockID)
```

And seven treatments:

``` r
levels(cover_thin$TTtreat) 
#> NULL
```

### Subsets

You can make filters and subsets by originSiteID, Site, Treatments.

Example of filter by originSiteID:

Example of filter by originPlotID == A1-1. You can create a new object:

or ask for the dimensions of a subset:

Example of multiple subsets of the data, by Site and Treatment:

Make a “fat” table (similar to cover) with a subset of the species per
Site

Ask which taxa appear at site A:

## Trait data

The traits data are stored in traits/data\_cleaned and are two files:
LeafTraits and ChemicalTraits. Read the csv files first.

``` r
traitsLeaf <- read_csv(file = "traits/data_cleaned/PFTC1.2_China_2015_2016_LeafTraits.csv", col_names = TRUE)

traitsChem <- read_csv(file = "traits/data_cleaned/PFTC1.2_China_2015_2016_ChemicalTraits.csv", col_names = TRUE)
```

We suggest start exploring the data sets, asking for the names of the
columns, the levels of each factor, and dimensions.

``` r
colnames(traitsLeaf)
#>  [1] "Envelope_Name_Corrected" "Date"                   
#>  [3] "Elevation"               "Site"                   
#>  [5] "destBlockID"             "Treatment"              
#>  [7] "Taxon"                   "Individual_number"      
#>  [9] "Leaf_number"             "Wet_Mass_g"             
#> [11] "Dry_Mass_g"              "Leaf_Thickness_1_mm"    
#> [13] "Leaf_Thickness_2_mm"     "Leaf_Thickness_3_mm"    
#> [15] "Leaf_Thickness_4_mm"     "Leaf_Thickness_5_mm"    
#> [17] "Leaf_Thickness_6_mm"     "Leaf_Thickness_Ave_mm"  
#> [19] "Leaf_Area_cm2"           "SLA_cm2_g"              
#> [21] "LDMC"                    "StoichLabel"            
#> [23] "WetFlag"                 "DryFlag"                
#> [25] "ThickFlag"               "AreaFlag"               
#> [27] "GeneralFlag"             "allComments"

colnames(traitsChem)
#>  [1] "Date"         "Elevation"    "Site"         "destBlockID"  "Treatment"   
#>  [6] "Taxon"        "StoichLabel"  "P_percent"    "C_percent"    "N_percent"   
#> [11] "CN_ratio"     "dN15_percent" "dC13_percent" "n"            "CNP_Comment"
```

Explore a bit the levels of each factor, and the variable names. They
have changed a bit compared to cover\_thin.

``` r
unique(traitsLeaf$Elevation)
#> [1] 3850 4100 3000 3500

unique(traitsLeaf$Treatment)
#> [1] "2"     "LOCAL" "3"     "0"     "C"     "OTC"   "1"     "4"

unique(traitsLeaf$Sites)
#> NULL
```

Quick example of a plot:

``` r
plot(x=log(traitsLeaf$Dry_Mass_g), y=log(traitsLeaf$Wet_Mass_g))
```

![](R_tutorial_China_files/figure-gfm/Trait%20data4-1.png)<!-- -->

### Trait Distributions

#### Data wrangling

Here is the code for plotting the traits distributions. Before ploting
the trait ditributions, we need to make some changes to the datasets and
log transform the variables, to finally merge the two trait data sets
into a single one.

First, you can see that Site is stored as “character”.

``` r
mode(traitsLeaf$Site)
#> [1] "character"
```

Step 1: For plotting purpuses is better to transform this variable to a
factor, with four levels (“H”, “A”, “M”, “L”). We will also log
transform the traits, this will help to reduce the skewness of the
values and to make the relationships between traits clearer.

``` r
traitsWideL <- traitsLeaf %>% 
  mutate(Wet_Mass_g.log = log(Wet_Mass_g),
         Dry_Mass_g.log = log(Dry_Mass_g),
         Leaf_Thickness_Ave_mm.log = log(Leaf_Thickness_Ave_mm),
         Leaf_Area_cm2.log = log(Leaf_Area_cm2)) %>% 
  mutate(Site = factor(Site, levels = c("H", "A", "M", "L"))) 
```

Step 2: New format to the leaf traits data, with traits and values in
two columns:

``` r
traitsLongL <- traitsWideL %>% 
  select(Date, Elevation, Site, Taxon, Individual_number, Leaf_number, Wet_Mass_g.log, Dry_Mass_g.log, Leaf_Thickness_Ave_mm.log, Leaf_Area_cm2.log, SLA_cm2_g, LDMC) %>% 
  gather(key = Traits, value = Value, -Date, -Elevation, -Site, -Taxon, -Individual_number, -Leaf_number)
```

Step 3: New format to the leaf Chemical traits (same manner). These
values are percentage, so we don´t need to log transform these traits:

``` r
traitsLongC <- traitsChem %>% 
  select(Date, Elevation, Site, Taxon, P_percent, C_percent, N_percent, CN_ratio, dN15_percent, dC13_percent) %>% 
  gather(key = Traits, value = Value, -Date, -Elevation, -Site, -Taxon)
```

Step 4: Bind the two data sets (Leaf and Chemical traits), using the two
“long” tables:

``` r
traitsLong <- traitsLongL %>% bind_rows(traitsLongC)
```

#### Density plot

Here is the code to plot the traits distributions, using density plots.
A density plot is similar to an histogram, and allows visualizing the
distribution of a numerical variable (it shows the interval and the
peaks of the distribution). The peaks of a density plot show where the
values are concentrated over the interval.

We want to plot the distribution of each invidual trait, at each site,
to visualize their variation.

So, first we filter the values containing NA´s, since we are not
interested in that and transform the Traits names into a factor (they
are stored as character).

Then, we plot it using ggplot. The values of each trait are going to
appear in the x coordinate (Value) and their frequency in coordinate y.
Density curves appear on different colors based on the Site (fill=Site).

geom\_density(alpha = 0.5) argument simply fills the density curves with
a transparent color.

facet\_wrap argument allows spliting the plot into the different Traits

``` r
TraitDist <- traitsLong %>% 
  filter(!is.na(Value)) %>% 
  mutate(Traits = factor(Traits, levels = c("Wet_Mass_g.log", "Dry_Mass_g.log", "Leaf_Thickness_Ave_mm.log", "Leaf_Area_cm2.log", "SLA_cm2_g", "LDMC", "P_percent", "C_percent", "N_percent", "CN_ratio", "dN15_percent", "dC13_percent"))) %>% 
  ggplot(aes(x = Value, fill = Site)) +
  geom_density(alpha = 0.5) +
  scale_fill_brewer(palette = "RdBu", direction = -1, labels=c("High alpine", "Alpine", "Middle", "Lowland")) +
  labs(x = "Mean trait value", y = "Density") +
  facet_wrap( ~ Traits, scales = "free") +
  theme(legend.position="top")

TraitDist
```

![](R_tutorial_China_files/figure-gfm/Density%20plot-1.png)<!-- -->

For saving the plot:

Exercise:

Try to plot the same density plot, but using only the values of one of
the treatments. For example, only the “LOCAL” values, or the “OTC”
values.

#### Boxplots

A different way of displaying the distribution of the data is using
boxplots. Boxplots are a graph showing how the values are spread out,
similarly to the density plots. Sometimes boxplots are more informative
that other measures of central tendencies like the mean.

``` r
TraitBoxp <- traitsLong %>% 
  filter(!is.na(Value)) %>% 
  mutate(Traits = factor(Traits, levels = c("Wet_Mass_g.log", "Dry_Mass_g.log", "Leaf_Thickness_Ave_mm.log", "Leaf_Area_cm2.log", "SLA_cm2_g", "LDMC","P_percent", "C_percent", "N_percent", "CN_ratio", "dN15_percent", "dC13_percent")))  %>% 
 mutate(Site = factor(Site, levels = c("L", "M", "A", "H"))) %>% 
 ggplot(aes(x=Site, y = Value, fill = Site)) +
 geom_boxplot() +
 scale_fill_brewer(palette = "RdBu", direction = -1,    labels=c("High alpine", "Alpine", "Middle", "Lowland"))+
  facet_wrap( ~ Traits, scales = "free") +
  theme(legend.position="top")

TraitBoxp
```

![](R_tutorial_China_files/figure-gfm/Boxplots-1.png)<!-- -->

### Traits scatterplots

This are just some scatterplots relating 2 traits values. Each dot is an
observation, and each coordinate represent the value of each of the
traits.

Some expamples:

``` r
DryWet <- traitsWideL %>% 
  ggplot(aes(x = Dry_Mass_g.log, y = Wet_Mass_g.log, colour = Site)) +
  geom_point(alpha = 0.4) +
  scale_color_brewer(palette = "RdBu", direction = -1, labels=c("High alpine", "Alpine", "Middle", "Lowland")) +
  theme(legend.position = "none")
```

``` r
DryArea <- traitsWideL %>% 
  ggplot(aes(x = Dry_Mass_g.log, y = Leaf_Area_cm2.log, colour = Site)) +
  geom_point(alpha = 0.4) +
  scale_color_brewer(palette = "RdBu", direction = -1, labels=c("High alpine", "Alpine", "Middle", "Lowland")) +
  theme(legend.position = "none")
```

``` r
AreaSLA <- traitsWideL %>% 
  ggplot(aes(x = Leaf_Area_cm2, y = SLA_cm2_g, colour = Site)) +
  geom_point(alpha = 0.4) +
  scale_color_brewer(palette = "RdBu", direction = -1, labels=c("High alpine", "Alpine", "Middle", "Lowland")) +
  theme(legend.position = "none")
```

``` r
LDMCThick <- traitsWideL %>% 
  ggplot(aes(x = LDMC, y = Leaf_Thickness_Ave_mm, colour = Site)) +
  geom_point(alpha = 0.4) +
  scale_color_brewer(palette = "RdBu", direction = -1, labels=c("High alpine", "Alpine", "Middle", "Lowland")) +
  theme(legend.position = "none")
```

``` r
Legend <- traitsWideL %>% 
  ggplot(aes(x = log(Leaf_Area_cm2), y = log(SLA_cm2_g), colour = Site)) +
  geom_point() +
  scale_color_brewer(palette = "RdBu", direction = -1, labels=c("High alpine", "Alpine", "Middle", "Lowland"))
```

``` r
l2 <- get_legend(Legend)

p3 <- plot_grid(DryWet, DryArea, AreaSLA, LDMCThick, ncol = 2)

Traits <- plot_grid(p3, l2, ncol = 2, rel_widths = c(1, 0.2))

Traits
```

![](R_tutorial_China_files/figure-gfm/Traits%20scatterplots6-1.png)<!-- -->

For saving the plot:

``` r
ggsave(Traits, filename = "Traits.jpg", height = 10, width = 10, dpi = 300)
```

### Traits means

We want to plot the mean values and standard error of each invidual
trait, at each site, and for each treatment separately. In the plots
that we did before we did not differenciate between treatments, but now
we do.

#### Data wrangling including treatment

As we did before, we need to make some changes to the datasets and log
transform the variables, to finally merge the two trait data sets into a
single one.

First, you can see that Site is stored as “character”.

``` r
mode(traitsLeaf$Site)
#> [1] "character"
```

Step 1: For plotting purpuses is better to transform this variable to a
factor, with four levels (“H”, “A”, “M”, “L”). We will also log
transform the traits, this will help to reduce the skewness of the
values and to make the relationships between traits clearer.

``` r
traitsWideL <- traitsLeaf %>% 
  mutate(Wet_Mass_g.log = log(Wet_Mass_g),
         Dry_Mass_g.log = log(Dry_Mass_g),
         Leaf_Thickness_Ave_mm.log = log(Leaf_Thickness_Ave_mm),
         Leaf_Area_cm2.log = log(Leaf_Area_cm2)) %>% 
  mutate(Site = factor(Site, levels = c("L", "M", "A", "H"))) 
```

Step 2: New format to the leaf traits data, with traits and values in
two columns. But now we want to include the Treatment information.

``` r
traitsLongL2 <- traitsWideL %>% 
  select(Date, Elevation, Site, Treatment, Taxon, Individual_number, Leaf_number, Wet_Mass_g.log, Dry_Mass_g.log, Leaf_Thickness_Ave_mm.log, Leaf_Area_cm2.log, SLA_cm2_g, LDMC) %>% 
  gather(key = Traits, value = Value, -Date, -Elevation, -Site, -Treatment, -Taxon, -Individual_number, -Leaf_number)
```

Step 3: New format to the leaf Chemical traits, but including the
Treatment information. These values are percentage, so we don´t need to
log transform these traits.

``` r
traitsLongC2 <- traitsChem %>% 
  select(Date, Elevation, Site,Treatment, Taxon, P_percent, C_percent, N_percent, CN_ratio, dN15_percent, dC13_percent) %>% 
  gather(key = Traits, value = Value, -Date, -Elevation, -Site, -Treatment, -Taxon)
```

Step 4: Bind the two data sets (Leaf and Chemical traits), using the two
“long” tables:

``` r
traitsLong2 <- traitsLongL2 %>% bind_rows(traitsLongC2)
```

#### Plot of the means per trait

We are going to plot the mean values and standard errors for each trait,
per site and treatment.

Step 1: Subset the data that we will need from traitsLong2. The columns
that we need are Site, Treatment, Traits and Values. We also need to
mutate the Site variable from character to a factor. If we order the
levels of a factor (for exameple Site), then these levels will appear in
the same order in the figures. So, we have order the levels of Site
following the elevation gradient: “L”, “M”, “A”,“H”

``` r
traitsL2 <- traitsLong2 %>%
  select(Site, Treatment, Traits, Value)%>%
  mutate(Site= factor(Site, levels=c("L", "M", "A","H")))
```

Step 2: Summarize the data. The next code, will make a summary table
with the mean values, stardard deviation and stardard errors, grouping
the column Value, by Trait, Treatment and Site.

I have excluded the values of “LOCAL” ***Be careful, the treatment
categories in the cover data and in the trait data do not match***

``` r
TraitsSE <- traitsL2 %>% 
  filter(!is.na(Value)) %>%
  filter(Treatment!= "LOCAL") %>%
  ddply(c("Traits", "Treatment","Site"), summarise,
               N    = length(Value),
               mean = mean(Value),
               sd   = sd(Value),
               se   = sd / sqrt(N))
```

Step 3: Make the plot. Define first the position\_dodge, this argument
allow you to move horizontaly the errors bars, so they don´t overlap.
Exercise: see what happens if you don´t define the position\_dodge, or
try to change the value.

``` r
pd <- position_dodge(0.4)

TraitsSE.p <- TraitsSE  %>% 
  mutate(Traits = factor(Traits, levels = c("Wet_Mass_g.log", "Dry_Mass_g.log", "Leaf_Thickness_Ave_mm.log", "Leaf_Area_cm2.log", "SLA_cm2_g", "LDMC", "P_percent", "C_percent", "N_percent", "CN_ratio", "dN15_percent", "dC13_percent"))) %>% 
  ggplot(aes(x = Site, y=mean,  colour=Treatment)) +
  geom_errorbar(aes(ymin=mean-se, ymax=mean+se), width=.1, position=pd) +
  geom_line(position=pd) +
  geom_point(position=pd)+
  labs(x = "Site", y = "Mean/se trait value") +
  facet_wrap( ~ Traits, scales = "free") +
  theme(legend.position="top")

TraitsSE.p 
```

![](R_tutorial_China_files/figure-gfm/Plot%20of%20the%20means%20per%20trait3-1.png)<!-- -->

For saving the plot:

``` r
ggsave(TraitsSE.p, filename = "TraitSE.jpg", height = 13, width = 13, dpi = 300)
```

### Community weighted means

Calculation of community weighted means. An easy example using only data
from 2012 and the Control plots.

#### Data wrangling

For the traits calculations we are going to use traitsLong2, you can
check above how we built this data frame. Now, select the variables
Site, Treatment, Taxon, Traits and Value

``` r
traitsL3 <- traitsLong2 %>%
  select(Site, Treatment, Taxon, Traits, Value)%>%
  mutate(Site= factor(Site, levels=c("L", "M", "A","H")))
```

##### Calculate mean trait values

And calculate the mean trait values for each taxon across sites and
treatments. Trait values can be assign in different ways. But now, we
are going to use mean trait values across sites and treatments for
simplicity.

``` r
traits.meanvalues <- traitsL3 %>% 
  filter(!is.na(Value)) %>%
  ddply(c("Traits","Taxon"), summarise,
        mean = mean(Value))%>%
  spread(key = Traits, value = mean)
```

##### Calculate the weights

Subset the cover data, by year and treatment, to include only 2012 and
Control plots. We are going to use the cover data of each species in
each site as a “weight” for calculating the community weighted means.

``` r
  cover_2012C <- cover_thin %>%
  filter(year == "2012")%>% # subset the year
  filter(TTtreat =="control")%>% # subset the control
  select(originSiteID, TTtreat, year, cover, speciesName) # select only a few variables (we dont need everything)
```

But…we can do the same for 2016…or for any year in the data

``` r
 cover_2016C <- cover_thin %>%
    filter(year == "2016")%>% # subset the year
    filter(TTtreat =="control")%>%#subset the control
    select(originSiteID, TTtreat, year, cover, speciesName)# select only a few variables (we dont need everything)
```

This are the species weights based on mean cover of each species at each
site in 2012 in the Control plots. Just a mean of the cover\!

``` r
spp.wts2012C <- cover_2012C %>% 
  ddply(c("originSiteID","speciesName"), summarise,
        wts = mean(cover))
```

Here the same for 2016, just for you to see…

``` r
spp.wts2016C <- cover_2016C %>% 
  ddply(c("originSiteID","speciesName"), summarise,
        wts = mean(cover))
```

Now, we need to merge the species weights with their mean trait values
in a single data frame, and we are going to use the column “Taxon” to
conect both data frame. But, the two data frames have different column
names for the species names as you will see here:

``` r
names(spp.wts2012C) # names of the columns or variables
#> [1] "originSiteID" "speciesName"  "wts"
names(traits.meanvalues) # names of the columns or variables 
#>  [1] "Taxon"                     "C_percent"                
#>  [3] "CN_ratio"                  "dC13_percent"             
#>  [5] "dN15_percent"              "Dry_Mass_g.log"           
#>  [7] "LDMC"                      "Leaf_Area_cm2.log"        
#>  [9] "Leaf_Thickness_Ave_mm.log" "N_percent"                
#> [11] "P_percent"                 "SLA_cm2_g"                
#> [13] "Wet_Mass_g.log"
```

So, first we are going to change the second column name in ssp.wts2012C
and call it “Taxon”, and after that we can merge the two tables.

``` r
names(spp.wts2012C)[2] <- "Taxon" # change the name of the second element

# and then merge:
traits.wts <- merge(spp.wts2012C, traits.meanvalues, by="Taxon")%>%
    arrange(originSiteID)
```

#### Calculate the CWM

So, for that we need a numeric vector of data values (the mean trait
value per species), x, and another numeric vector of weights (cover of
each species in each site), w. The weighted mean is the sum of the data
value times the weights divided by the sum of the weights. Note that x
and w should have the same number of elements. In R, it is calculated
with weighted.mean(), which does sum(x \* w) / sum(w).

There we go:

Step 1: Summarize the CWM for each trait

``` r
summarize.traits.cwm.W <-   # New dataframe where we can inspect the result
  traits.wts %>%   # Data frame with the weights
  ddply(c("originSiteID"), summarise,  # Coding for how we want our CWMs summarized
        # Actual calculation of CWMs
        Wet_Mass_g.log = weighted.mean(Wet_Mass_g.log, wts, na.rm=TRUE), 
        Dry_Mass_g.log = weighted.mean(Dry_Mass_g.log, wts, na.rm=TRUE),
        Leaf_Thickness_Ave_mm.log = weighted.mean(Leaf_Thickness_Ave_mm.log, wts, na.rm=TRUE),
        Leaf_Area_cm2.log = weighted.mean(Leaf_Area_cm2.log, wts, na.rm=TRUE),
        SLA_cm2_g = weighted.mean(SLA_cm2_g, wts, na.rm=TRUE), 
        LDMC = weighted.mean(LDMC, wts, na.rm=TRUE),
        P_percent = weighted.mean(P_percent, wts, na.rm=TRUE),
        C_percent = weighted.mean(C_percent, wts, na.rm=TRUE),   
        N_percent = weighted.mean(N_percent, wts, na.rm=TRUE),
        CN_ratio = weighted.mean(CN_ratio, wts, na.rm=TRUE),
        dN15_percent = weighted.mean(dN15_percent, wts, na.rm=TRUE),
        dC13_percent = weighted.mean(dC13_percent, wts, na.rm=TRUE))

summarize.traits.cwm.L <- summarize.traits.cwm.W  %>%
  gather(Traits, CWM, "Wet_Mass_g.log", "Dry_Mass_g.log", "Leaf_Thickness_Ave_mm.log", "Leaf_Area_cm2.log", "SLA_cm2_g", "LDMC", "P_percent", "C_percent", "N_percent", "CN_ratio", "dN15_percent", "dC13_percent")
```

Step 2: Plot

``` r
pd <- position_dodge(0.4)

TraitsCWM <- summarize.traits.cwm.L  %>% 
  mutate(Traits = factor(Traits, levels = c("Wet_Mass_g.log", "Dry_Mass_g.log", "Leaf_Thickness_Ave_mm.log", "Leaf_Area_cm2.log", "SLA_cm2_g", "LDMC", "P_percent", "C_percent", "N_percent", "CN_ratio", "dN15_percent", "dC13_percent"))) %>% 
  mutate(originSiteID = factor(originSiteID, levels = c("L", "M", "A", "H"))) %>%
  ggplot(aes(x = originSiteID, y=CWM)) +
  geom_point(position=pd, shape=17, colour="blue") +
  labs(x = "Site", y = "CWM", title="Control plots 2012") +
  facet_wrap( ~ Traits, scales = "free") +
  theme(legend.position="top", plot.title = element_text(size = (15)))              

TraitsCWM 
```

![](R_tutorial_China_files/figure-gfm/unnamed-chunk-12-1.png)<!-- -->

So, try adding 2016 data:

Now, try to add the CWM of the year 2016 for the control plots. We
already have prepared the weights (spp.wts2016C) and the
cover(cover\_2016C) So, we have to change the column names in
spp.wts2016C before doing the merge

``` r
names(spp.wts2016C)[2] <- "Taxon"
```

But, before merging the two data sets, we need to bind the data from
2012, and 2016. So, add a column year to each, and then bind by rows…so
rbind

``` r
# The traits values are the same! but not the weights! do create the column year to differenciate

spp.wts2012C$year <- rep(2012, length(spp.wts2012C$Taxon))
spp.wts2016C$year <- rep(2016, length(spp.wts2016C$Taxon))

# bind the two data sets with the weights for 2012 and the weights for 2016.
wts2012_2016 = rbind(spp.wts2012C,spp.wts2016C)
head(wts2012_2016)
#>   originSiteID              Taxon      wts year
#> 1            H Aletris pauciflora  2.80000 2012
#> 2            H     Allium prattii  2.22000 2012
#> 3            H    Androsace minor  5.50000 2012
#> 4            H    Anemone demissa  3.50000 2012
#> 5            H   Caltha palustris  3.05000 2012
#> 6            H          Carex spp 12.44286 2012

wts2012_2016$year <- as.factor(wts2012_2016$year) # transform to a factor, so it has two levels

# and finally do the merge!

traits.wts <- merge(wts2012_2016, traits.meanvalues, by="Taxon")%>%
  arrange(originSiteID)
```

There we go:

Step 1: Summarize the CWM for each trait (but now we also group by year
for calculating)

``` r
summarize.traits.cwm.W <-   # New dataframe where we can inspect the result
  traits.wts %>%   # Data frame with the weights
  ddply(c("originSiteID", "year"), summarise,  
        # Coding for how we want our CWMs summarized (by oririginSiteID and also YEAR!!)
        # Actual calculation of CWMs
        Wet_Mass_g.log = weighted.mean(Wet_Mass_g.log, wts, na.rm=TRUE), 
        Dry_Mass_g.log = weighted.mean(Dry_Mass_g.log, wts, na.rm=TRUE),
        Leaf_Thickness_Ave_mm.log = weighted.mean(Leaf_Thickness_Ave_mm.log, wts, na.rm=TRUE),
        Leaf_Area_cm2.log = weighted.mean(Leaf_Area_cm2.log, wts, na.rm=TRUE),
        SLA_cm2_g = weighted.mean(SLA_cm2_g, wts, na.rm=TRUE), 
        LDMC = weighted.mean(LDMC, wts, na.rm=TRUE),
        P_percent = weighted.mean(P_percent, wts, na.rm=TRUE),
        C_percent = weighted.mean(C_percent, wts, na.rm=TRUE),   
        N_percent = weighted.mean(N_percent, wts, na.rm=TRUE),
        CN_ratio = weighted.mean(CN_ratio, wts, na.rm=TRUE),
        dN15_percent = weighted.mean(dN15_percent, wts, na.rm=TRUE),
        dC13_percent = weighted.mean(dC13_percent, wts, na.rm=TRUE))
  
  summarize.traits.cwm.L <- summarize.traits.cwm.W  %>%
  gather(Traits, CWM, "Wet_Mass_g.log", "Dry_Mass_g.log", "Leaf_Thickness_Ave_mm.log", "Leaf_Area_cm2.log", "SLA_cm2_g", "LDMC", "P_percent", "C_percent", "N_percent", "CN_ratio", "dN15_percent", "dC13_percent")
```

Step 2: Plot, but specify that you want the different years in different
colors\!

``` r
pd <- position_dodge(0.4)

TraitsCWM <- summarize.traits.cwm.L  %>% 
  mutate(Traits = factor(Traits, levels = c("Wet_Mass_g.log", "Dry_Mass_g.log", "Leaf_Thickness_Ave_mm.log", "Leaf_Area_cm2.log", "SLA_cm2_g", "LDMC", "P_percent", "C_percent", "N_percent", "CN_ratio", "dN15_percent", "dC13_percent"))) %>% 
   mutate(originSiteID = factor(originSiteID, levels = c("L", "M", "A", "H"))) %>%
  ggplot(aes(x = originSiteID, y=CWM, colour=year)) +
  geom_point(position=pd, shape=17) +
  labs(x = "Site", y = "CWM", title="Control plots 2012-2016") +
  facet_wrap( ~ Traits, scales = "free") +
  theme(legend.position="top", plot.title = element_text(size = (15)))              


TraitsCWM 
```

![](R_tutorial_China_files/figure-gfm/unnamed-chunk-16-1.png)<!-- -->
