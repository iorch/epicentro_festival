#Leemos datos del inegi.
#Es archivo de excel con dos hojas. Las separamos en dos archivos .csv
setwd('C:/Users/PABLOD/Dropbox/Datatón/')
inegi1<- read.csv("RESAGEBURB_14XLS10.csv", header=T, colClasses="factor", na.strings="*")
inegi2<- read.csv("RESAGEBURB_14XLS102.csv", header=T, colClasses="factor", na.strings="*")

#juntamos en una sola variable
inegi<- rbind(inegi1,inegi2)

#descartamos la informacion a nivel manzana
jefas<- inegi[inegi[,"NOM_LOC"]=="Total AGEB urbana" ,c("ENTIDAD", "MUN", "LOC",  "AGEB","HOGJEF_F", "PRO_OCUP_C", "VPH_INTER", "VIVPAR_HAB")]
jefas2<- data.frame(CVEGEO=paste(jefas[,1], jefas[,2], jefas[,3], jefas[,4], sep=""), cant_jefas=jefas[,5], pro_ocup_c=jefas[,6], vph_inter=jefas[,7], vivpar_hab=jefas[,8])
jefas2[,2]<- as.numeric(matrix(jefas2[,2]))
jefas2[,1]<- as.character(jefas2[,1])
jefas2[,3]<- as.numeric(matrix(jefas2[,3]))
jefas2[,4]<- as.numeric(matrix(jefas2[,4]))
jefas2[,5]<- as.numeric(matrix(jefas2[,5]))
rownames(jefas)<- NULL


#leemos datos de apoyos a jefas
apoyojefas<- read.csv("apoyomujeresjefasfamiliadatatonsedis03112014.csv", header=T) 
apoyojefas$CVEGEO2 <- substr(apoyojefas$CVEGEO,1,13)

#quitamos agebs rurales 
apoyojefas<- apoyojefas[which(apoyojefas$CVEGEO2 %in% jefas2[,1]),]


#contamos los apoyos por AGEB
csvegeos = levels(as.factor(apoyojefas$CVEGEO2))
jefascount = data.frame(CVEGEO2=csvegeos, apoyos=0)
for ( csvegeo in csvegeos ) {
  jefascount[jefascount[1]==csvegeo,'apoyos'] <- length(apoyojefas[apoyojefas$CVEGEO2 == csvegeo,1])
}

#densidad jefas
jefas.frac<- jefas2$cant_jefas/jefas2$vivpar_hab


#indice de marginacion
ocupc<- jefas2[,"pro_ocup_c"]
ocupc[jefas2[,"pro_ocup_c"]>2]<- 2
inter<- jefas2[,"vph_inter"]

 
margin<- data.frame(CVGEO=jefas2[,1], IM=0)
for(i in 1:nrow(jefas2))
{
  margin[i,2]<- (1-inter[i]/jefas2[i,"vivpar_hab"] + ocupc[i]/2)/2
}


#llenado de NA's
vars<- data.frame(cant=jefas2[,2], dens=jefas.frac, margin=margin[,2])

library(missForest)
vars.imp<- missForest(vars, verbose=T)
vars.imp$ximp$cant<- round(vars.imp$ximp$cant,0)
vars.imp$ximp$dens<- round(vars.imp$ximp$dens,6)
vars.imp$ximp$margin<- round(vars.imp$ximp$margin, 6) 

Ind.desat.imp<- data.frame(CVGEO=jefas2[,1], cant=vars.imp$ximp$cant, dens=vars.imp$ximp$dens, margin=vars.imp$ximp$margin, porc.ap=0, ind.desat=0)


#porcentaje de jefas apoyadas
for( cvgeo in jefas2[,1])
{
  if (!(cvgeo %in% csvegeos))
  {
    Ind.desat.imp$porc.ap[Ind.desat.imp$CVGEO==cvgeo]<- 0
  }
  else
  {
    Ind.desat.imp$porc.ap[Ind.desat.imp$CVGEO==cvgeo] <- jefascount[jefascount[,1]==cvgeo,"apoyos"]/jefas2[jefas2[,1]==cvgeo,2]
  }    
}



#nivel de demanda - regresion
log.porc.imp<- log(Ind.desat.imp$porc.ap)
log.porc.imp[which(!is.finite(log.porc.imp))]<- NA


reglin<- lm(log.porc.imp ~ Ind.desat.imp$margin + Ind.desat.imp$dens + Ind.desat.imp$cant)
par(mfrow=c(2,2))
plot(reglin)


#Indice de desatencion
Ind.desat.imp$ind.desat<- exp(reglin$coefficients[1] + reglin$coefficients[2]*Ind.desat.imp$margin + reglin$coefficients[3]*Ind.desat.imp$dens + reglin$coefficients[4]*Ind.desat.imp$cant) - Ind.desat.imp$porc.ap
View(Ind.desat.imp)

write.csv(Ind.desat.imp, file="C:/Users/PABLOD/Dropbox/Datatón/ind_desat_jefas.csv")

