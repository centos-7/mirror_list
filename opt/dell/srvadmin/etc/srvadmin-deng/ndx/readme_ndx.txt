#//-------------------------------------------------------------------------
#//
#//                 Dell Inc. PROPRIETARY INFORMATION
#//
#//  This software is supplied under the terms of a license agreement or
#//  nondisclosure agreement with Dell Inc. and may not be copied or
#//  disclosed except in accordance with the terms of that agreement.
#//
#//  Copyright (c) 1995-2011 Dell Inc. All Rights Reserved.
#//
#//  Abstract/Purpose:
#//    NDX configuration file README
#//
#//-------------------------------------------------------------------------

#//-------------------------------------------------------------------------
#//
#// Naming Convention
#// -----------------
#// Please use caution in assigning values to the name-value pairs in this
#// document. For each entry pair, either the name, or the value, or both
#// will be used to generate an XML string/document. 
#// 
#// An example of value-only XML generation is the "bitmap" definition.
#// Each entry defines a numeric bitmap position followed by a value string
#// which will be used to generate an XML.
#//
#// An example of name-only XML generation is the "ObjNameToCXM" definition.
#// Each entry defines a value CXM filename prefix to an object name which
#// will be used to generate an XML.
#//
#// Another example is when defining a struct in a CXM file. The naming
#// restriction applies to the struct variable name and the struct name
#// itself.
#//
#// In general, use the following guidelines on creating an entry in this
#// document. For a "name" and/or "value" in a name-value pair entry: always
#// start the string with a "letter" or "_" (underscore). No whitespaces in
#// front or in between. subsequent characters may be of the following
#// ( Letter | Digit | '.' | '-' | '_' | ':' ). 
#//
#// When in doubt, always test the application to verify that your entry
#// generates a valid XML or, at a higher level, properly displays.
#// For more info, please reference the XML specification under 
#// http://www.w3.org/TR/REC-xml and search for "start-tag".
#//
#//-------------------------------------------------------------------------

#//-------------------------------------------------------------------------
#//
#// SMReqRsp Configuration Format
#// -----------------------------
#// The following describes the format of the DA set request/response
#// configuration. This configuration is referenced from the
#// SMReqRspRegister section of a component's NDX registration file.
#//
#// [PROPERTYNAME]
#//	PROPERTYNAME is the da setid created in the <component-id>ndx.ini
#//	file under section SMReqRspRegister.  For example, isndx.ini for
#//	the instrumentation service.  The entry in the ndx.ini follows the 
#//	following format:
#//		PROPERTYNAME=<basename of ini and cxm files>
#//
#// <req>
#// exec.daplugin=<opt>
#// 	Specifies the prefix name of the da plugin that implements the set.  
#//     This implements functionality required for a custom set. A custom 
#//     set is one that requires extra/custom processing.
#// description=<req>
#// 	String describing the set functionality. User visible through the 
#//     DA help system.
#// objtype.list=<req>: otl
#// 	Pointer to section containing the object type list.
#// 
#// <req>
#// req.objname=<req>
#// 	Pointer to entry in the cxm (C-to-XML map) file.
#// req.type=<req>
#// 	Request id extracted from dchipreq.h or equivalent header. For example,
#//		SM_SET_ASSET_TAG = (SM_SET_TYPE_HIP_LO_1 + 0x32) = 306
#// req.ispassthru=<opt>: booln, defaults to false if not specified
#//	Indicates whether request is pass-thru or not.  Request goes directly
#//	to populator without data manager updating the object repository.
#// req.sdobody=<opt>: booln, defaults to false if not specified
#//	Set to true if the target object is an SDO (Self Describing Object).
#// req.followup.var=<opt>
#//	Return variable name when the request is pass-thru.
#// req.followup.var.def.val=<opt>
#//	Default variable for req.followup.var.
#// 
#// <opt>
#// rsp.objname=<req>
#//	Response object name for pass-thru requests.
#// rsp.sdobody=<opt>: booln, defaults to false if not specified
#//	Set to true if the response object is an SDO (Self Describing Object).
#// rsp.followup.var=<opt>
#//	Default variable for rsp.followup.var.
#// 
#// <opt>
#// log.eventid=<req>: u32
#//	Defines the log event identifier.
#// log.enable=<opt>: booln, defaults to false if not specified
#//	Enables logging for the set.
#// log.category=<req>: u16
#//	Defines the log category.
#// log.typeonerr=<opt>: u16, defaults to 1
#//	The log type to use on an error condition
#// log.typeonsuc=<opt>: u16, defaults to 0
#//	The log type to use on a success status
#// log.parameter.list=<opt>: lpl, empty if not specified
#//	Pointer to section containing the log parameter list.
#// 
#// [otl]
#// NUMBER=BOOLN	// defaults to true if not specified
#// ...
#//	List of object type that set applies to.  ex. 0x0111=true
#//	A value of false blocks sets to the object.
#// 
#// [lpl]
#// NAME=(none|all|oldonly|newonly)	// defaults to all if not specified
#// ...
#//	Parameter list to log.  Specifies the following:
#//		none     - do not log the parameter.
#//		all      - logs old and new values for the parameter.
#//		oldonly  - logs old value for the parameter.
#//		newonly  - logs new value for the parameter.
#//
#//-------------------------------------------------------------------------


#//-------------------------------------------------------------------------
#// End
#//-------------------------------------------------------------------------
