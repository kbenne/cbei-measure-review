#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#load OpenStudio measure libraries
require "#{File.dirname(__FILE__)}/resources/OsLib_HelperMethods"
#start the measure
class AddExhaustFanToZoneBasedOnSpaceType < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return " Add Exhaust Fan to Zone based on Space Type"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # create an argument for a space type to be used in the model, to see if one should be mapped as ceiling return air plenum
    spaceTypes = model.getSpaceTypes
    usedSpaceTypes_handle = OpenStudio::StringVector.new
    usedSpaceTypes_displayName = OpenStudio::StringVector.new
    spaceTypes.each do |spaceType|  #todo - I need to update this to use helper so GUI sorts by display name
      if spaceType.spaces.size > 0 # only show space types used in the building
        usedSpaceTypes_handle << spaceType.handle.to_s
        usedSpaceTypes_displayName << spaceType.name.to_s
      end
    end
	
	# make an optional argument for space type to add exhaust fan
    addtoSpaceType = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("addtoSpaceType", usedSpaceTypes_handle, usedSpaceTypes_displayName,false)
    addtoSpaceType.setDisplayName("Add Zone Exhaust Fan to this space type")
    args << addtoSpaceType
	
	# make an argument exhaust fan ACH (Air Change per Hour)
    exhaustFanACH = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("exhaustFanACH",true)
    exhaustFanACH.setDisplayName("Zone Exhaust Fan Air Changes per Hour")
    exhaustFanACH.setDefaultValue(1.0)
    args << exhaustFanACH
	
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    ### START INPUTS
    #assign the user inputs to variables
	addtoSpaceType = runner.getOptionalWorkspaceObjectChoiceValue("addtoSpaceType", user_arguments, model)
	exhaustFanACH = runner.getDoubleArgumentValue("exhaustFanACH",user_arguments)
	addtoSpaceTypeCheck = OsLib_HelperMethods.checkOptionalChoiceArgFromModelObjects(addtoSpaceType, "addtoSpaceType", "to_SpaceType", runner, user_arguments)
	if addtoSpaceTypeCheck==false then return false else addtoSpaceType=addtoSpaceTypeCheck["modelObject"] end 
	
	# get thermal zones
	zones = model.getThermalZones
	spaces = addtoSpaceType.spaces
	spaces.each do |space|	  
		if space.thermalZone.is_initialized
		  thermal_zone = space.thermalZone.get
		  volume = space.volume
		  zoneFinished = false
		  thermal_zone.equipment.each do |equip|
		    if equip.to_FanZoneExhaust.is_initialized
			  equip.setMaximumFlowRate (volume*exhaustFanACH/3600.0)
			  zoneFinished= true
		    end
		  end
		  unless zoneFinished
			fanZoneExhaust = OpenStudio::Model::FanZoneExhaust.new(model)
			fanZoneExhaust.setMaximumFlowRate ( volume * exhaustFanACH/3600.0)
			# fanZoneExhaust.setMaximumFlowRate ( 0.05)
			fanZoneExhaust.setPressureRise (125)
			fanZoneExhaust.setFanEfficiency (0.6)
			fanZoneExhaust.setSystemAvailabilityManagerCouplingMode("coupled")
			fanZoneExhaust.addToThermalZone(thermal_zone)
		  end
	  end
	end
	
  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddExhaustFanToZoneBasedOnSpaceType.new.registerWithApplication