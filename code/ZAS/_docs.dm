/*

Zone Air System:

This air system divides the station into impermeable areas called zones.
When something happens, i.e. a door opening or a wall being taken down,
zones equalize and eventually merge. Making an airtight area closes the connection again.

Control Flow:
Every air tick:
	Marked turfs are updated with update_air_properties(), followed by post_update_air_properties().
	Edges, including those generated by connections in the previous step, are processed. This is where gas is exchanged.
	Fire is processed.
	Marked zones have their air archived.

Important Functions:

air_master.mark_for_update(turf)
	When stuff happens, call this. It works on everything. You basically don't need to worry about any other
	functions besides CanPass().

Notes for people who used ZAS before:
	There is no connected_zones anymore.
	To get the zones that are connected to a zone, use this loop:
	for(var/connection_edge/zone/edge in zone.edges)
		var/zone/connected_zone = edge.get_connected_zone(zone)

*/

//#define ZASDBG
//#define ZLEVELS

#define AIR_BLOCKED 1
#define ZONE_BLOCKED 2
#define BLOCKED 3

#define ZONE_MIN_SIZE 14 //zones with less than this many turfs will always merge, even if the connection is not direct

