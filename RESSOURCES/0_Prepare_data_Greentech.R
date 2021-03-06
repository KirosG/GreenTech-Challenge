  #--------------------------------------------------------------------------------------------------#
  #                                                                                                  #
  #		Concours GreenTech : CREATION ENVIRONNEMENT R                                                #
  #   Objectif : préparer les données et les sauver en RData pour optimiser le temps de chargement   #
  #                                                                                                  #
  #		Script made with love by The SuperViz team                                                   #
  #                                                                                                  #
  #--------------------------------------------------------------------------------------------------#


# Définition du répertoire de travail
setwd("~/Your_Path/GreenTech_challenge/") 


#------------------------------
# Moyenne Pesticide Historique
#------------------------------

    # Liste de tous les fichiers par année
    files.ma_qp  <- list.files("DATA/Moyennes_analyses_pesticides dans eaux souterraines_HISTORIQUE/fichiers csv",pattern=glob2rx("*.csv"), full.names = TRUE)
    
    # Chargement et concaténation des fichiers
    pest_db <- do.call(rbind.data.frame, lapply(files.ma_qp, function(f){
      
      df <- read.table(f, header=T , sep=";", quote="", stringsAsFactors = FALSE)
      annee  <- strsplit(f, "_")[[1]]
      annee <- annee[length(annee)]
      annee <- gsub(".csv","",annee)
      df$ANNEE <- as.numeric(annee)
      
      return(df)
      
    }))

    rm(files.ma_qp)

    pest_db$MA_MOY <- gsub(",",".",pest_db$MA_MOY)
    pest_db$MA_MOY <- as.numeric(pest_db$MA_MOY)
    
    # Nettoyage des valeurs aberrantes de concentration
    pest_db <- pest_db[-which(pest_db$MA_MOY>1),] # Supprime peu de lignes, et Q3 = 0.025ug/l

    pest_db$CD_STATION <- as.character(pest_db$CD_STATION)
    pest_db$ANNEE <- as.numeric(pest_db$ANNEE)
    pest_db$NORME_DCE <- as.numeric(gsub(",",".",pest_db$NORME_DCE))
  
#--------------------
# Données pesticides 
#--------------------
  
    pesticide=read.table("DATA/Pesticides/pesticides.csv" , header=T , sep=";" , quote="")
      
    # Petit nettoyage de 3 pesticides en double qui foutent la merde
    pesticide <- pesticide[-which(pesticide$CD_PARAMETRE==1177 & pesticide$LB_PARAMETRE=="Diuron desmethyl"),]
    pesticide <- pesticide[-which(pesticide$CD_PARAMETRE==1208 & pesticide$LB_PARAMETRE=="Isoproturon desmethyl"),]
    pesticide <- pesticide[-which(pesticide$CD_PARAMETRE==1141 & pesticide$LB_PARAMETRE=="2,4-D methyl ester"),]
    
    # Codage en colonne de la famille de pesticide, avec pour chaque famille 1 si le pesticide appartient à la famille, 0 si non
    pesticide$Acaricide <- 0
    #pesticide$Biocide <- 0 # Il n'y en a pas
    pesticide$Fongicide <- 0
    pesticide$Herbicide <- 0
    pesticide$Mollusticide <- 0
    pesticide$Nematicide <- 0
    pesticide$Insecticide <- 0
    pesticide$Reg_croiss <- 0
    pesticide$Rodenticide <- 0
    pesticide$Repulsif <- 0
    #pesticide$Graminicide <- 0 #  Il n'y en a pas
    pesticide$NO_FUNCTION <- 0
    
    pesticide$Acaricide[grep("A",pesticide$CODE_FONCTION)] <- 1
    pesticide$Fongicide[grep("F",pesticide$CODE_FONCTION)] <- 1
    pesticide$Herbicide[grep("H",pesticide$CODE_FONCTION)] <- 1
    pesticide$Mollusticide[grep("M",pesticide$CODE_FONCTION)] <- 1
    pesticide$Nematicide[grep("N",pesticide$CODE_FONCTION)] <- 1
    pesticide$Insecticide[grep("I",pesticide$CODE_FONCTION)] <- 1
    pesticide$Rodenticide[grep("Ro",pesticide$CODE_FONCTION)] <- 1
    pesticide$Reg_croiss[c(grep("Reg",pesticide$CODE_FONCTION),grep("reg",pesticide$CODE_FONCTION))] <- 1
    pesticide$Repulsif[grep("Rep()",pesticide$CODE_FONCTION)] <- 1
    pesticide$NO_FUNCTION[grep("PP",pesticide$CODE_FONCTION)] <- 1
    pesticide$NO_FUNCTION[which(pesticide$CODE_FONCTION=="")] <- 1


#--------------------
# Données stations 
#--------------------
  
    # Changement accent de l'en tête à la main...
    station=read.table("DATA/Stations/stations.csv" , header=T , sep=";" , na.strings="", dec="," , quote="", row.names = NULL)
    
    # On garde uniquement les stations qui ont au moins une année avec des relevés
    station <- station[which(is.element(station$CD_STATION, pest_db$CD_STATION)),]
    
    # On recalcule les latitudes et longitudes à partir des coordonnées projetées en lambert93
    library(rgdal)
    library(rgeos)
    tmp=station
    coordinates(tmp) <- ~X_FICT_L93+Y_FICT_L93
    proj4string(tmp) <- "+proj=lcc +lat_1=49 +lat_2=44 +lat_0=46.5 +lon_0=3 +x_0=700000 +y_0=6600000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
    tmp=spTransform(tmp , "+proj=longlat +datum=WGS84 +no_defs" ) 
    station=cbind(station, coordinates(tmp))
    colnames(station)[c(28,29)]=c("LONG","LAT")
    rm(tmp)


#---------------------------------------------------
# Shapefiles départements + régions + masses d'eau
#---------------------------------------------------
  
    ME=readOGR( dsn= "DATA/Polygone MasseDEauSouterraine_VEDL2013_FXX-shp/Polygones_ME_ultralight.shp" , layer="Polygones_ME_ultralight") 
    regions=readOGR( dsn= "DATA/Regions/regions-20140306-100m.shp" , layer="regions-20140306-100m")
    departements=readOGR(dsn= "DATA/Departements/", layer="departements-20140306-100m")
    departements@data$nom <- NULL
    departements@data$nuts3 <- NULL
    departements@data$wikipedia <- NULL
    colnames(departements@data) <- "Numero"
    departements@data$Numero <- as.character(departements@data$Numero)
    departements <- departements[-which(nchar(departements@data$Numero)==3),]
    dep  <- read.table("DATA/Departements/departements.csv", sep=";",dec=".",header=TRUE)
    dep$Région <- NULL
    colnames(dep) <- c("Numero","Nom","Region")
    dep$Numero <- as.character(dep$Numero)
    dep$Numero[which(nchar(dep$Numero)==1)] <- paste0("0",dep$Numero[which(nchar(dep$Numero)==1)])
    departements@data <- merge(departements@data, dep, all.x=TRUE, all.y=FALSE)
    departements@data$Nom <- as.character(departements@data$Nom)
    departements@data$Region <- as.character(departements@data$Region)
    departements@data$Region[departements@data$Region=="Languedoc-Roussillon-Midi-Pyrénées"] <- "Occitanie"
    
    # On joint les polygones par ID (problème des nouvelles régions)
    regions <- regions[-which(regions@data$nom %in% c("Guadeloupe","Guyane","Martinique","La Réunion","Mayotte")),]
    regions@data$nom <- as.character(regions@data$nom)
    regions@data$Region <- regions@data$nom
    regions@data$Region[regions@data$Region %in% c("Alsace","Champagne-Ardenne","Lorraine")] <- "Alsace-Champagne-Ardenne-Lorraine"
    regions@data$Region[regions@data$Region %in% c("Aquitaine","Limousin","Poitou-Charentes")] <- "Aquitaine-Limousin-Poitou-Charentes"
    regions@data$Region[regions@data$Region %in% c("Auvergne","Rhône-Alpes")] <- "Auvergne-Rhône-Alpes"
    regions@data$Region[regions@data$Region %in% c("Haute-Normandie","Basse-Normandie")] <- "Normandie"
    regions@data$Region[regions@data$Region %in% c("Bourgogne","Franche-Comté")] <- "Bourgogne-Franche-Comté"
    regions@data$Region[regions@data$Region %in% c("Languedoc-Roussillon","Midi-Pyrénées")] <- "Occitanie"
    regions@data$Region[regions@data$Region %in% c("Nord-Pas-de-Calais","Picardie")] <- "Nord-Pas-de-Calais-Picardie"
    regions@data$Region[regions@data$Region %in% "Île-de-France"] <- "Ile-de-France"
    regions@data$Region[regions@data$Region %in% "Pays de la Loire"] <- "Pays-de-la-Loire"
    regions <- gUnaryUnion(regions, id=regions@data$Region)
    df <- data.frame("Region"=sapply(1:length(regions), function(i)regions@polygons[[i]]@ID))
    row.names(df) <- df$Region
    region <- SpatialPolygonsDataFrame(regions, data=df)
    rm(regions, df, dep)


#-----------------------------------------------------------------------------------------------
# pest_db: Rajout des infos sur les stations, familles et fonctions de pesticides, région et ME 
#-----------------------------------------------------------------------------------------------


    # Informations stations
    pest_db=merge(pest_db, station[,c("CD_STATION","NUM_COM","NOM_COM","NUM_DEP","LONG","LAT")], 
                       by.x="CD_STATION", by.y="CD_STATION" , all.x=T)
    
    # Informations pesticides: fonction et famille
    pest_db=merge(pest_db, pesticide[ , c(1,4,6,14:23)], by.x="CD_PARAMETRE", by.y="CD_PARAMETRE" , all.x=T)
    pest_db=droplevels(pest_db)
      
    # Informations région et ME
    pest_db <- merge(pest_db, departements@data[,c("Numero","Region")], by.x = "NUM_DEP", by.y="Numero", all.x=TRUE, all.y=FALSE)
    pest_db <- merge(pest_db, station[,c("CD_STATION","CD_ME_niv1_surf")], all.x=TRUE, all.y=FALSE)
	
  
#------------------------------------------------------
# pest_station: Préparation des agrégations par station 
#------------------------------------------------------  

  
    # Concentration totale sur toutes les molécules
    pest_station.Ctot <- aggregate(MA_MOY~CD_STATION+ANNEE, data=pest_db, sum,na.rm=TRUE)
    colnames(pest_station.Ctot) <- c("CD_STATION","ANNEE","VALEUR")
    pest_station.Ctot$Niveau <- "Ctot"  
    
    
    # Concentration totale par famille
    pest_station.Famille <- aggregate(MA_MOY~CD_STATION+CODE_FAMILLE+ANNEE, data=pest_db, sum,na.rm=TRUE)
    colnames(pest_station.Famille) <- c("CD_STATION","CODE_FAMILLE","ANNEE","VALEUR")
    pest_station.Famille$Niveau <- "Famille"
      
    # Concentration totale par fonction
    pest_station.Fonction <- do.call(rbind.data.frame, lapply(c("Acaricide","Fongicide","Herbicide","Mollusticide","Nematicide","Insecticide","Reg_croiss","Rodenticide","Repulsif"), function(func){
      
      df <- pest_db[pest_db[,func]==1, c("MA_MOY", "CD_STATION","ANNEE")]
      df <- aggregate(MA_MOY~., data=df, sum,na.rm=TRUE)
      df$Fonction <- func
      return(df)
    }))
    colnames(pest_station.Fonction) <- c("CD_STATION","ANNEE","VALEUR","FONCTION")
    pest_station.Fonction$Niveau <- "Fonction"
    
    # NbSup
    pest_db.TEMP <- pest_db
    pest_db.TEMP$SupSeuil <- 0
    pest_db.TEMP$SupSeuil[which(pest_db.TEMP$MA_MOY > pest_db.TEMP$NORME_DCE)] <- 1
    pest_station.NbSup <- aggregate(SupSeuil~CD_STATION+ANNEE, data=pest_db.TEMP, sum,na.rm=TRUE)
    colnames(pest_station.NbSup) <- c("CD_STATION","ANNEE","VALEUR")
    pest_station.NbSup$Niveau <- "NbSup"
    
    # NbMolQuant et PropMolQuant
    pest_station.NbMolQuant <- aggregate(NBQUANTIF~CD_STATION+ANNEE, data=pest_db, sum,na.rm=TRUE)
    pest_station.PropMolQuant <- aggregate(NBANASPERTS1~CD_STATION+ANNEE, data=pest_db, sum,na.rm=TRUE)
    pest_station.PropMolQuant$NBANASPERTS1 <- pest_station.NbMolQuant$NBQUANTIF / pest_station.PropMolQuant$NBANASPERTS1
    colnames(pest_station.PropMolQuant) <- c("CD_STATION","ANNEE","VALEUR")
    pest_station.PropMolQuant$Niveau <- "PropMolQuant"
    colnames(pest_station.NbMolQuant) <- c("CD_STATION","ANNEE","VALEUR")
    pest_station.NbMolQuant$Niveau <- "NbMolQuant"
    
    # NbPNA
    pest_db.TEMP <- pest_db[pest_db$NBQUANTIF>0,]
    pest_db.TEMP$PNA <- 0
    pest_db.TEMP$PNA[which(pest_db.TEMP$STATUT == "PNA")] <- 1
    
    pest_station.NbPNA <- aggregate(PNA~CD_STATION+ANNEE, data=pest_db.TEMP, sum,na.rm=TRUE)
    colnames(pest_station.NbPNA) <- c("CD_STATION","ANNEE","VALEUR")
    pest_station.NbPNA$Niveau <- "NbPNA"
    
      
    
    # On rbind toutes ces tables
    names <- c("CD_STATION","CODE_FAMILLE","FONCTION","ANNEE","VALEUR","Niveau")
    
    pest_station <- NA
    for (table in c("pest_station.Ctot","pest_station.Famille","pest_station.Fonction",
                    "pest_station.NbSup","pest_station.NbMolQuant","pest_station.PropMolQuant", "pest_station.NbPNA")){
      
      df <- get(table)
      df[,names[which(!is.element(names, colnames(df)))]] <- NA
      df <- df[,names]
      
      pest_station <- rbind(pest_station,df)
      
    }#eo for table
    pest_station <- pest_station[-1,]
    rownames(pest_station) <- NULL
      
    rm(pest_station.Ctot, pest_station.Famille, pest_station.Fonction, pest_station.NbMolQuant, 
       pest_station.NbPNA, pest_station.NbSup, pest_station.PropMolQuant, pest_db.TEMP, df)
      
    # On rajoute LAT et LONG en colonnes pour éviter d'avoir à le faire en live pour plotter les valeurs
    pest_station <- merge(pest_station, station[,c("CD_STATION","LONG","LAT")], all.x=TRUE, all.y=FALSE)


#--------------------------------------------------------------
# pest_departement: Préparation des agrégations par departement 
#--------------------------------------------------------------  


    # Concentration molécule par molécule
    pest_departement.Ci <- aggregate(MA_MOY~CD_STATION+LB_PARAMETRE+ANNEE+NUM_DEP, data=pest_db, sum,na.rm=TRUE)
    pest_departement.Ci <- aggregate(MA_MOY~NUM_DEP+LB_PARAMETRE+ANNEE, data=pest_departement.Ci, mean,na.rm=TRUE)
    colnames(pest_departement.Ci) <- c("NUM_DEP","LB_PARAMETRE","ANNEE","VALEUR")
    pest_departement.Ci$Niveau <- "Ci"  
      
    # Concentration totale sur toutes les molécules
    pest_departement.Ctot <- aggregate(MA_MOY~CD_STATION+ANNEE+NUM_DEP, data=pest_db, sum,na.rm=TRUE)
    pest_departement.Ctot <- aggregate(MA_MOY~NUM_DEP+ANNEE, data=pest_departement.Ctot, mean,na.rm=TRUE)
    colnames(pest_departement.Ctot) <- c("NUM_DEP","ANNEE","VALEUR")
    pest_departement.Ctot$Niveau <- "Ctot"  
    
    
    # Concentration totale par famille
    pest_departement.Famille <- aggregate(MA_MOY~CD_STATION+CODE_FAMILLE+ANNEE+NUM_DEP, data=pest_db, sum,na.rm=TRUE)
    pest_departement.Famille <- aggregate(MA_MOY~NUM_DEP+CODE_FAMILLE+ANNEE, data=pest_departement.Famille, mean,na.rm=TRUE)
    colnames(pest_departement.Famille) <- c("NUM_DEP","CODE_FAMILLE","ANNEE","VALEUR")
    pest_departement.Famille$Niveau <- "Famille"
    
    # Concentration totale par fonction
    pest_departement.Fonction <- do.call(rbind.data.frame, lapply(c("Acaricide","Fongicide","Herbicide","Mollusticide","Nematicide","Insecticide","Reg_croiss","Rodenticide","Repulsif"), function(func){
      
      df <- pest_db[which(pest_db[,func]==1), c("MA_MOY", "CD_STATION","ANNEE","NUM_DEP")]
      df <- aggregate(MA_MOY~CD_STATION+ANNEE+NUM_DEP, data=df, sum,na.rm=TRUE)
      df <- aggregate(MA_MOY~NUM_DEP+ANNEE, data=df, mean,na.rm=TRUE)
      df$Fonction <- func
      return(df)
    }))
    colnames(pest_departement.Fonction) <- c("NUM_DEP","ANNEE","VALEUR","FONCTION")
    pest_departement.Fonction$Niveau <- "Fonction"
    
    # NbSup
    pest_db.TEMP <- pest_db
    pest_db.TEMP$SupSeuil <- 0
    pest_db.TEMP$SupSeuil[which(pest_db.TEMP$MA_MOY > pest_db.TEMP$NORME_DCE)] <- 1
    pest_departement.NbSup <- aggregate(SupSeuil~CD_STATION+ANNEE+NUM_DEP, data=pest_db.TEMP, sum,na.rm=TRUE)
    pest_departement.NbSup <- aggregate(SupSeuil~NUM_DEP+ANNEE, data=pest_departement.NbSup, mean,na.rm=TRUE)
    colnames(pest_departement.NbSup) <- c("NUM_DEP","ANNEE","VALEUR")
    pest_departement.NbSup$Niveau <- "NbSup"
    
    # NbMolQuant et PropMolQuant
    pest_departement.NbMolQuant <- aggregate(NBQUANTIF~CD_STATION+ANNEE+NUM_DEP, data=pest_db, sum,na.rm=TRUE)
    pest_departement.PropMolQuant <- aggregate(NBANASPERTS1~CD_STATION+ANNEE+NUM_DEP, data=pest_db, sum,na.rm=TRUE)
    pest_departement.PropMolQuant$NBANASPERTS1 <- pest_departement.NbMolQuant$NBQUANTIF / pest_departement.PropMolQuant$NBANASPERTS1
    pest_departement.PropMolQuant <- aggregate(NBANASPERTS1~NUM_DEP+ANNEE, data=pest_departement.PropMolQuant, mean,na.rm=TRUE)
    colnames(pest_departement.PropMolQuant) <- c("NUM_DEP","ANNEE","VALEUR")
    pest_departement.PropMolQuant$Niveau <- "PropMolQuant"
    pest_departement.NbMolQuant <- aggregate(NBQUANTIF~NUM_DEP+ANNEE, data=pest_departement.NbMolQuant, mean,na.rm=TRUE)
    colnames(pest_departement.NbMolQuant) <- c("NUM_DEP","ANNEE","VALEUR")
    pest_departement.NbMolQuant$Niveau <- "NbMolQuant"
    
    # NbPNA
    pest_db.TEMP <- pest_db[pest_db$NBQUANTIF>0,]	
    pest_db.TEMP$PNA <- 0
    pest_db.TEMP$PNA[which(pest_db.TEMP$STATUT == "PNA")] <- 1
    
    pest_departement.NbPNA <- aggregate(PNA~CD_STATION+ANNEE+NUM_DEP, data=pest_db.TEMP, sum,na.rm=TRUE)
    pest_departement.NbPNA <- aggregate(PNA~NUM_DEP+ANNEE, data=pest_departement.NbPNA, mean,na.rm=TRUE)
    colnames(pest_departement.NbPNA) <- c("NUM_DEP","ANNEE","VALEUR")
    pest_departement.NbPNA$Niveau <- "NbPNA"
    
    
    
    # On rbind toutes ces tables
    names <- c("NUM_DEP","LB_PARAMETRE","CODE_FAMILLE","FONCTION","ANNEE","VALEUR","Niveau")
    
    pest_departement <- NA
    for (table in c("pest_departement.Ci","pest_departement.Ctot","pest_departement.Famille","pest_departement.Fonction",
                    "pest_departement.NbSup","pest_departement.NbMolQuant","pest_departement.PropMolQuant", "pest_departement.NbPNA")){
      
      df <- get(table)
      df[,names[which(!is.element(names, colnames(df)))]] <- NA
      df <- df[,names]
      
      pest_departement <- rbind(pest_departement,df)
      
    }#eo for table
    pest_departement <- pest_departement[-1,]
    rownames(pest_departement) <- NULL
    
    rm(pest_departement.Ci, pest_departement.Ctot, pest_departement.Famille, pest_departement.Fonction, pest_departement.NbMolQuant, 
       pest_departement.NbPNA, pest_departement.NbSup, pest_departement.PropMolQuant, pest_db.TEMP, df, names, table)


#-----------------------------------------------------
# pest_region: Préparation des agrégations par region 
#-----------------------------------------------------  


    # Concentration molécule par molécule
    pest_region.Ci <- aggregate(MA_MOY~CD_STATION+LB_PARAMETRE+ANNEE+Region, data=pest_db, sum,na.rm=TRUE)
    pest_region.Ci <- aggregate(MA_MOY~Region+LB_PARAMETRE+ANNEE, data=pest_region.Ci, mean,na.rm=TRUE)
    colnames(pest_region.Ci) <- c("Region","LB_PARAMETRE","ANNEE","VALEUR")
    pest_region.Ci$Niveau <- "Ci"  
    
    # Concentration totale sur toutes les molécules
    pest_region.Ctot <- aggregate(MA_MOY~CD_STATION+ANNEE+Region, data=pest_db, sum,na.rm=TRUE)
    pest_region.Ctot <- aggregate(MA_MOY~Region+ANNEE, data=pest_region.Ctot, mean,na.rm=TRUE)
    colnames(pest_region.Ctot) <- c("Region","ANNEE","VALEUR")
    pest_region.Ctot$Niveau <- "Ctot"  
    
    
    # Concentration totale par famille
    pest_region.Famille <- aggregate(MA_MOY~CD_STATION+CODE_FAMILLE+ANNEE+Region, data=pest_db, sum,na.rm=TRUE)
    pest_region.Famille <- aggregate(MA_MOY~Region+CODE_FAMILLE+ANNEE, data=pest_db, mean,na.rm=TRUE)
    colnames(pest_region.Famille) <- c("Region","CODE_FAMILLE","ANNEE","VALEUR")
    pest_region.Famille$Niveau <- "Famille"
    
    # Concentration totale par fonction
    pest_region.Fonction <- do.call(rbind.data.frame, lapply(c("Acaricide","Fongicide","Herbicide","Mollusticide","Nematicide","Insecticide","Reg_croiss","Rodenticide","Repulsif"), function(func){
      
      df <- pest_db[which(pest_db[,func]==1), c("MA_MOY","CD_STATION","ANNEE","Region")]
      df <- aggregate(MA_MOY~CD_STATION+ANNEE+Region, data=df, sum,na.rm=TRUE)
      df <- aggregate(MA_MOY~Region+ANNEE, data=df, mean,na.rm=TRUE)
      df$Fonction <- func
      return(df)
    }))
    colnames(pest_region.Fonction) <- c("Region","ANNEE","VALEUR","FONCTION")
    pest_region.Fonction$Niveau <- "Fonction"
    
    # NbSup
    pest_db.TEMP <- pest_db
    pest_db.TEMP$SupSeuil <- 0
    pest_db.TEMP$SupSeuil[which(pest_db.TEMP$MA_MOY > pest_db.TEMP$NORME_DCE)] <- 1
    pest_region.NbSup <- aggregate(SupSeuil~CD_STATION+ANNEE+Region, data=pest_db.TEMP, sum,na.rm=TRUE)
    pest_region.NbSup <- aggregate(SupSeuil~Region+ANNEE, data=pest_region.NbSup, mean,na.rm=TRUE)
    colnames(pest_region.NbSup) <- c("Region","ANNEE","VALEUR")
    pest_region.NbSup$Niveau <- "NbSup"
    
    # NbMolQuant et PropMolQuant
    pest_region.NbMolQuant <- aggregate(NBQUANTIF~CD_STATION+ANNEE+Region, data=pest_db, sum,na.rm=TRUE)
    pest_region.PropMolQuant <- aggregate(NBANASPERTS1~CD_STATION+ANNEE+Region, data=pest_db, sum,na.rm=TRUE)
    pest_region.PropMolQuant$NBANASPERTS1 <- pest_region.NbMolQuant$NBQUANTIF / pest_region.PropMolQuant$NBANASPERTS1
    pest_region.PropMolQuant <- aggregate(NBANASPERTS1~Region+ANNEE, data=pest_region.PropMolQuant, mean,na.rm=TRUE)
    colnames(pest_region.PropMolQuant) <- c("Region","ANNEE","VALEUR")
    pest_region.PropMolQuant$Niveau <- "PropMolQuant"
    pest_region.NbMolQuant <- aggregate(NBQUANTIF~Region+ANNEE, data=pest_region.NbMolQuant, mean,na.rm=TRUE)
    colnames(pest_region.NbMolQuant) <- c("Region","ANNEE","VALEUR")
    pest_region.NbMolQuant$Niveau <- "NbMolQuant"
    
    # NbPNA
    pest_db.TEMP <- pest_db[pest_db$NBQUANTIF>0,]
    pest_db.TEMP$PNA <- 0
    pest_db.TEMP$PNA[which(pest_db.TEMP$STATUT == "PNA")] <- 1
    
    pest_region.NbPNA <- aggregate(PNA~CD_STATION+ANNEE+Region, data=pest_db.TEMP, sum,na.rm=TRUE)
    pest_region.NbPNA <- aggregate(PNA~Region+ANNEE, data=pest_region.NbPNA, mean,na.rm=TRUE)
    colnames(pest_region.NbPNA) <- c("Region","ANNEE","VALEUR")
    pest_region.NbPNA$Niveau <- "NbPNA"
    
    
    
    # On rbind toutes ces tables
    names <- c("Region","LB_PARAMETRE","CODE_FAMILLE","FONCTION","ANNEE","VALEUR","Niveau")
    
    pest_region <- NA
    for (table in c("pest_region.Ci","pest_region.Ctot","pest_region.Famille","pest_region.Fonction",
                    "pest_region.NbSup","pest_region.NbMolQuant","pest_region.PropMolQuant", "pest_region.NbPNA")){
      
      df <- get(table)
      df[,names[which(!is.element(names, colnames(df)))]] <- NA
      df <- df[,names]
      
      pest_region <- rbind(pest_region,df)
      
    }#eo for table
    pest_region <- pest_region[-1,]
    rownames(pest_region) <- NULL
    
    rm(pest_region.Ci, pest_region.Ctot, pest_region.Famille, pest_region.Fonction, pest_region.NbMolQuant, 
       pest_region.NbPNA, pest_region.NbSup, pest_region.PropMolQuant, pest_db.TEMP, df, names, table)
    

#---------------------------------------------
# pest_ME: Préparation des agrégations par ME 
#---------------------------------------------  


    # Concentration molécule par molécule
    pest_ME.Ci <- aggregate(MA_MOY~CD_STATION+LB_PARAMETRE+ANNEE+CD_ME_niv1_surf, data=pest_db, sum,na.rm=TRUE)
    pest_ME.Ci <- aggregate(MA_MOY~CD_ME_niv1_surf+LB_PARAMETRE+ANNEE, data=pest_ME.Ci, mean,na.rm=TRUE)
    colnames(pest_ME.Ci) <- c("ME","LB_PARAMETRE","ANNEE","VALEUR")
    pest_ME.Ci$Niveau <- "Ci"  
      
    # Concentration totale sur toutes les molécules
    pest_ME.Ctot <- aggregate(MA_MOY~CD_STATION+ANNEE+CD_ME_niv1_surf, data=pest_db, sum,na.rm=TRUE)
    pest_ME.Ctot <- aggregate(MA_MOY~CD_ME_niv1_surf+ANNEE, data=pest_ME.Ctot, mean,na.rm=TRUE)
    colnames(pest_ME.Ctot) <- c("ME","ANNEE","VALEUR")
    pest_ME.Ctot$Niveau <- "Ctot"  
    
    
    # Concentration totale par famille
    pest_ME.Famille <- aggregate(MA_MOY~CD_STATION+CODE_FAMILLE+ANNEE+CD_ME_niv1_surf, data=pest_db, sum,na.rm=TRUE)
    pest_ME.Famille <- aggregate(MA_MOY~CD_ME_niv1_surf+CODE_FAMILLE+ANNEE, data=pest_ME.Famille, mean,na.rm=TRUE)
    colnames(pest_ME.Famille) <- c("ME","CODE_FAMILLE","ANNEE","VALEUR")
    pest_ME.Famille$Niveau <- "Famille"
    
    # Concentration totale par fonction
    pest_ME.Fonction <- do.call(rbind.data.frame, lapply(c("Acaricide","Fongicide","Herbicide","Mollusticide","Nematicide","Insecticide","Reg_croiss","Rodenticide","Repulsif"), function(func){
      
      df <- pest_db[which(pest_db[,func]==1), c("MA_MOY", "CD_STATION","ANNEE","CD_ME_niv1_surf")]
      df <- aggregate(MA_MOY~CD_STATION+ANNEE+CD_ME_niv1_surf, data=df, sum,na.rm=TRUE)
      df <- aggregate(MA_MOY~CD_ME_niv1_surf+ANNEE, data=df, mean,na.rm=TRUE)
      df$Fonction <- func
      return(df)
    }))
    colnames(pest_ME.Fonction) <- c("ME","ANNEE","VALEUR","FONCTION")
    pest_ME.Fonction$Niveau <- "Fonction"
    
    # NbSup
    pest_db.TEMP <- pest_db
    pest_db.TEMP$SupSeuil <- 0
    pest_db.TEMP$SupSeuil[which(pest_db.TEMP$MA_MOY > pest_db.TEMP$NORME_DCE)] <- 1
    pest_ME.NbSup <- aggregate(SupSeuil~CD_STATION+ANNEE+CD_ME_niv1_surf, data=pest_db.TEMP, sum,na.rm=TRUE)
    pest_ME.NbSup <- aggregate(SupSeuil~CD_ME_niv1_surf+ANNEE, data=pest_ME.NbSup, mean,na.rm=TRUE)
    colnames(pest_ME.NbSup) <- c("ME","ANNEE","VALEUR")
    pest_ME.NbSup$Niveau <- "NbSup"
    
    # NbMolQuant et PropMolQuant
    pest_ME.NbMolQuant <- aggregate(NBQUANTIF~CD_STATION+ANNEE+CD_ME_niv1_surf, data=pest_db, sum,na.rm=TRUE)
    pest_ME.PropMolQuant <- aggregate(NBANASPERTS1~CD_STATION+ANNEE+CD_ME_niv1_surf, data=pest_db, sum,na.rm=TRUE)
    pest_ME.PropMolQuant$NBANASPERTS1 <- pest_ME.NbMolQuant$NBQUANTIF / pest_ME.PropMolQuant$NBANASPERTS1
    pest_ME.PropMolQuant <- aggregate(NBANASPERTS1~CD_ME_niv1_surf+ANNEE, data=pest_ME.PropMolQuant, mean,na.rm=TRUE)
    colnames(pest_ME.PropMolQuant) <- c("ME","ANNEE","VALEUR")
    pest_ME.PropMolQuant$Niveau <- "PropMolQuant"
    pest_ME.NbMolQuant <- aggregate(NBQUANTIF~CD_ME_niv1_surf+ANNEE, data=pest_ME.NbMolQuant, mean,na.rm=TRUE)
    colnames(pest_ME.NbMolQuant) <- c("ME","ANNEE","VALEUR")
    pest_ME.NbMolQuant$Niveau <- "NbMolQuant"
    
    # NbPNA
    pest_db.TEMP <- pest_db[pest_db$NBQUANTIF>0,]
    pest_db.TEMP$PNA <- 0
    pest_db.TEMP$PNA[which(pest_db.TEMP$STATUT == "PNA")] <- 1
    
    pest_ME.NbPNA <- aggregate(PNA~CD_STATION+ANNEE+CD_ME_niv1_surf, data=pest_db.TEMP, sum,na.rm=TRUE)
    pest_ME.NbPNA <- aggregate(PNA~CD_ME_niv1_surf+ANNEE, data=pest_ME.NbPNA, mean,na.rm=TRUE)
    colnames(pest_ME.NbPNA) <- c("ME","ANNEE","VALEUR")
    pest_ME.NbPNA$Niveau <- "NbPNA"
    
    
    
    # On rbind toutes ces tables
    names <- c("ME","LB_PARAMETRE","CODE_FAMILLE","FONCTION","ANNEE","VALEUR","Niveau")
    
    pest_ME <- NA
    for (table in c("pest_ME.Ci","pest_ME.Ctot","pest_ME.Famille","pest_ME.Fonction",
                    "pest_ME.NbSup","pest_ME.NbMolQuant","pest_ME.PropMolQuant", "pest_ME.NbPNA")){
      
      df <- get(table)
      df[,names[which(!is.element(names, colnames(df)))]] <- NA
      df <- df[,names]
      
      pest_ME <- rbind(pest_ME,df)
      
    }#eo for table
    pest_ME <- pest_ME[-1,]
    rownames(pest_ME) <- NULL
    
    rm(pest_ME.Ci, pest_ME.Ctot, pest_ME.Famille, pest_ME.Fonction, pest_ME.NbMolQuant, 
       pest_ME.NbPNA, pest_ME.NbSup, pest_ME.PropMolQuant, pest_db.TEMP, df, names, table)

  
  
# On ne garde que les masses d'eau superficielles
ME <- ME[which(ME@data$CdMssDE %in% intersect(ME@data$CdMssDE, unique(pest_db$CD_ME_niv1_surf))),]
  
  
  
  
#-------------------------------------------------
# Calcul du barplot des pesticide les plus courant
#-------------------------------------------------

    # Calcul: pour chaque pesticide, combien de fois il a était vu au dessus du seuil de 0.1?
    c=aggregate(pest_db$MA_MOY , by=list(pest_db$LB_PARAMETRE) , function(x){ length(x[x>0.1])}  )
    # horizontal barplot
    #library(ggplot2)
    #my_barplot=ggplot(head(c[order(c$x , decreasing=T) , ]) , aes(y=x , x=Group.1, color=Group.1, fill=Group.1)) + geom_bar(stat = "identity", width=0.3) + coord_flip() + xlab("") + ylab("") + theme(legend.pos="none")


#-------------------------------------
# Ajout dangerosité fichier pesticide
#-------------------------------------

    # Chargement des données de toxicité (noms traduits et corrigés à la main)
    alltox <- read.csv('DATA/Pesticides/ld50_values_list_matching.csv',sep=',', header=TRUE, na.strings=c("–", "-",""))

    # On modifie le format
    alltox$LD50 <- as.numeric(levels(alltox$LD50))[alltox$LD50]
    alltox$moleculename_fr <- as.character(alltox$moleculename_fr)
    alltox$moleculename_en <- as.character(alltox$moleculename_en)
    alltox$productname <- as.character(alltox$productname)

    # On supprime les valeurs NA
    alltox <- alltox[-which(is.na(alltox$LD50)==TRUE),]

    # On ne garde que les pesticides de la liste officielle
    tox <- subset.data.frame(alltox, hasmatch==TRUE)

    # Les autres pesticides (non officiels)
    othertox <- subset.data.frame(alltox, hasmatch==FALSE)

    # Petit nettoyage de 3 petits problemes:
    tox=tox[-which(tox$moleculename_fr=="Aldicarbe" & tox$fonction=="FongicidesandNematicides"), ]
    tox=tox[-which(tox$moleculename_fr=="Terbuphos" & tox$fonction=="FongicidesandNematicides"), ]
    tox=tox[-which(tox$moleculename_fr=="sulfate tribasique de cuivre" & tox$fonction=="FongicidesandNematicides"), ]

    # On ajoute ces informations au fichier pesticide
    pesticide=merge(pesticide , tox, by.x="LB_PARAMETRE", by.y="moleculename_fr" , all.x=T)

    # On peux aggréger avec l'importance de chaque pesticide
    colnames(c)[2]="importance_pest"
    pesticide=merge(pesticide , c, by.x="LB_PARAMETRE", by.y="Group.1" , all.x=T)
    
    rm(tox, alltox, othertox)

#-----------------------------------------------
# Fonction pour crééer les palettes de couleurs
#-----------------------------------------------
    
    getPalette <- function(inFile=inFile, threshold=0.1){
      
      jet.colors.green <- colorRampPalette(c("#008A0C","#FFFF80")) #c("#3D9970","#FFFFCC"))
      colourCodes.green <- jet.colors.green(5)    
      jet.colors.red <- colorRampPalette(c("#FFFF80","#D10000")) #c("#FFFFCC","#DD171E"))
      colourCodes.red <- jet.colors.red(5)
      
      MAX <- max(inFile@data[,grep("y20",colnames(inFile@data))], na.rm=T)
      if (MAX>threshold){
        
        colourCodes <- c(colourCodes.green[1:4], colourCodes.red)
        
        bins = c(seq(0,threshold,length.out = 6)[1:5], 
                 seq(from = threshold,to = MAX, length.out = 5))
      
        palette <- colorBin(colourCodes, bins = bins, na.color = "grey")
        
      }else{
        
        colourCodes <- colourCodes.green
        
        bins = c(seq(0,threshold,length.out = 6))
    
        palette <- colorBin(colourCodes, bins = bins, na.color = "grey")
        
      }#eo if	
      
      bins <- round(bins,2)
      bins <- paste(bins[1:(length(bins)-1)], bins[2:length(bins)], sep=" - ")
      
      return(list("palette"=palette, "bins"=bins, "colourCodes"=colourCodes))
      
    }#eo function getPalette
	
	
	
# ================================================== #
# ========= On sauvegarde l'environnement ========== #
# ================================================== #
  
    # On ne garde pas les objets par masse d'eau en l'état car shapefile corrompu
    rm(ME, pest_ME)
    save.image("DATA/env_greentech.R")


# --------------------------------------------------------------------------
