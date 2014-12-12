#!/usr/bin/env ruby
#encoding: utf-8

inegi = File.open('./RESAGEBURB_14TXT10.txt','r')

apoyos_jefas = File.open('./apoyomujeresjefasfamiliadatatonsedis03112014.csv','r')
apoyos_adultos = File.open('./atencionadultosmayoresdatatonsedis03112014.csv','r')

coverage_of_program = 0.30

for_ageb = {}
totohog  = {}
header = []
counter = 0
inegi.each do |line|
    line.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    linev =  line.sub("\n",'').sub("\r",'').split("\t")
    if counter == 0
        header = linev
        counter = counter + 1
        next
    end
    counter = counter + 1
    next unless linev[5] == 'Total AGEB urbana'
    index = 0
    ageb = linev[0]+linev[2]+linev[4]+linev[6]
    for_ageb[ageb] = {}
    linev.each do |field|
        for_ageb[ageb][header[index]] = field
        index = index + 1
    end
    for_ageb[ageb]['APOYOS_JEFAS'] = 0
    for_ageb[ageb]['APOYOS_AMAYORES'] = 0
end

counter = 0
apoyos_jefas.each do |line|
    counter = counter + 1
    next if counter == 1
    linev =  line.sub("\n",'').split(',')
    ageb = linev[2][0..12]
    for_ageb[ageb] = for_ageb[ageb].nil? ? {} : for_ageb[ageb]
    for_ageb[ageb]['APOYOS_JEFAS'] = for_ageb[ageb]['APOYOS_JEFAS'].nil? ? 1 : for_ageb[ageb]['APOYOS_JEFAS']+1
end

counter = 0
apoyos_adultos.each do |line|
    counter = counter + 1
    next if counter == 1
    linev =  line.sub("\n",'').split(',')
    ageb = linev[2][0..12]
    for_ageb[ageb] = for_ageb[ageb].nil? ? {} : for_ageb[ageb]
    for_ageb[ageb]['APOYOS_AMAYORES'] = for_ageb[ageb]['APOYOS_AMAYORES'].nil? ? 1 : for_ageb[ageb]['APOYOS_AMAYORES']+1
end

#------------------
# read conapo and priority data

require 'csv'

dataton = CSV.read('./conapo.csv',
  :col_sep =>",", 
  :headers => true)

# list with data by ageb conapo  
margin_conapo = {}

dataton.each do |row|
  ageb = row['CVEGEO'][0..12]
  margin_conapo[ageb] = row['IMU2010'].to_f
end

#normalize marginacion
maxMargin = margin_conapo.values.max
minMargin = margin_conapo.values.min

puts 'minMargin'
puts minMargin
puts 'maxMargin'
puts maxMargin


margin_conapo.each do |ageb,value|
  margin_conapo[ageb] = (value - minMargin)/(maxMargin - minMargin)
end

priority = CSV.read('./priority.csv',
  :col_sep =>",", 
  :headers => true)

# list with data by ageb priority 
for_ageb_priority = {}

priority.each do |row|
  ageb = row['CVEGEO'][0..12]
  for_ageb_priority[ageb] = {}
  for_ageb_priority[ageb]['AGEB'] = ageb
end

# get common keys
keys_conapo = (for_ageb.keys & margin_conapo.keys)
keys_priority = (keys_conapo & for_ageb_priority.keys)

# use common keys
for_ageb = Hash[keys_conapo.zip(for_ageb.values_at(*keys_conapo))]

# add marginacion
for_ageb.keys.each do |ageb|
  for_ageb[ageb]['IMU2010'] = margin_conapo[ageb]
end

#------------------

result = {}
histo_index = {0.0 => 0, 0.1 => 0, 0.2 => 0, 0.3 => 0, 0.4 => 0, 0.5 => 0, 0.6 => 0,0.7 => 0, 0.8 => 0, 0.9 => 0}
marginacion_apoyos_jefas = {0.0 => [], 0.2 => [], 0.4 => [], 0.6 => [], 0.8 => []}
marginacion_apoyos_mayores = {0.0 => [], 0.2 => [], 0.4 => [], 0.6 => [], 0.8 => []}
marginacion_apoyos_mayores_avg = {0.0 => -4.974973144795865, 0.2 => -3.691307516722584, 0.4 => -2.5667605396934987, 0.6 => -2.427620124970888, 0.8 => -2.3426553891986934}
marginacion_apoyos_jefas_avg = {0.0 => -4.410329842999902, 0.2 => -4.54124678660976, 0.4 => -3.809979008824915, 0.6 => -3.381390712964752, 0.8 => -1}
fraction_of_population = {0.0=>0.074, 0.1=>0.015, 0.2=>0.037, 0.3=>0.038, 0.4=>0.067, 0.5=>0.109, 0.6=>0.217, 0.7=>0.242, 0.8=>0.136, 0.9=>0.059}
cummulative_fraction = {0.0=>0.074, 0.1=>0.089, 0.2=>0.126, 0.3=>0.164, 0.4=>0.231, 0.5=>0.34, 0.6=>0.557, 0.65=>0.67 , 0.7=>0.799, 0.75=>0.87 ,0.8=>0.935, 0.85=>0.965, 0.9=>0.994}
priority_limit =  cummulative_fraction.dup.keep_if{|key,val| val < 1-coverage_of_program}.keys.max
calibrated_index = File.open('./calibrated_index.csv','w') do |file|
counter = 0
for_ageb.each do |ageb,values|
    output = []
    jefas_frac = values['TOTHOG'].to_i==0 ? 0.0 : values['HOGJEF_F'].to_f/values['TOTHOG'].to_f
    adultos_mayor_frac = values['TOTHOG'].to_i==0 ? 0.0 : values['POB65_MAS'].to_f/values['TOTHOG'].to_f
    tmp_a = values['TVIVHAB'].to_i==0 ? 0.0 : 1.0 - values['VPH_INTER'].to_f/values['TVIVHAB'].to_f
    tmp_b = values['PRO_OCUP_C'].to_i>=2.0 ? 1.0 : values['PRO_OCUP_C'].to_f/2.0
    marginacion = values['IMU2010']
    bin = ((marginacion-0.0001)*10).to_i/10.0
    histo_index[bin] = histo_index[bin].to_i + 1 #values['POBTOT'].to_i
    jefas_apoyadas = values['HOGJEF_F'].to_i==0 ? 0.0 : values['APOYOS_JEFAS'].to_f/values['HOGJEF_F'].to_f
    mayores_apoyados = values['POB65_MAS'].to_i==0 ? 0.0 : values['APOYOS_AMAYORES'].to_f/values['POB65_MAS'].to_f

    prioridad_jefas = jefas_frac*marginacion/priority_limit>1.0 ? 1.0 : jefas_frac*marginacion/priority_limit
    prioridad_adultos = adultos_mayor_frac*marginacion/priority_limit>1.0 ? 1.0 : adultos_mayor_frac*marginacion/priority_limit
    
    #desatencion_jefas = (marginacion/priority_limit)*values['HOGJEF_F'].to_i==0 ? 0.0 : ((marginacion/priority_limit)*values['HOGJEF_F'].to_i-values['APOYOS_JEFAS'].to_i)/(marginacion/priority_limit)/values['HOGJEF_F'].to_i
    
    #desatencion_adultos = (marginacion/priority_limit)*values['POB65_MAS'].to_i==0? 0.0 : ((marginacion/priority_limit)*values['POB65_MAS'].to_i-values['APOYOS_AMAYORES'].to_i)/(marginacion/priority_limit)/values['POB65_MAS'].to_i

    bin = ((marginacion-0.0001)*5).to_i/5.0
    marginacion_apoyos_jefas[bin] << Math::log(jefas_apoyadas) unless jefas_apoyadas ==0.0
    #marginacion_apoyos_mayores[bin] << Math::log(mayores_apoyados) unless mayores_apoyados==0.0
    
    
    header = %w( ageb jefas_frac adultos_mayor_frac marginacion jefas_apoyadas mayores_apoyados desatencion_jefas desatencion_adultos)
    
    desatencion_jefas_nueva = jefas_apoyadas - Math.exp(marginacion*2.698 - 5.252)
    desatencion_mayores_nueva = mayores_apoyados - [0,[marginacion*0.24666 - 0.03885, 0.60575*0.24666 - 0.03885].min].max
    
    output << ageb
    output << [jefas_frac, 0.4].min
    output << [adultos_mayor_frac, 0.4].min
    output << marginacion
    output << [jefas_apoyadas, 0.05].min
    output << [mayores_apoyados, 0.05].min
    output << desatencion_jefas_nueva
    output << desatencion_mayores_nueva
    counter = counter+1
    file.puts header.join(',') unless counter!=1
    file.puts output.join(',')
end
end

#p marginacion_apoyos_mayores.values.map{|vector| vector.reduce(:+)/vector.size}
#p marginacion_apoyos_jefas.values.map{|vector| vector.reduce(:+)/vector.size}


#tot = histo_index.values.reduce(:+).to_f
#histo_index.each{ |key,val| histo_index[key] = (1000*val/tot).to_i/1000.0 }
#p histo_index
#p histo_index.values.reduce(:+)


#result.each { |ageb,value|
#    p "#{ageb},#{value}"
#}