open Rrd_protocol

let get_extra_data_sources_flag =
	let counter = ref 0 in
	(fun () ->
		let result = match !counter / 8 with
		| 0 -> false
		| _ -> true
		in
		if !counter >= 15 then counter := 0 else incr counter;
		result)

let generate_time_data_source () =
	let current_time = Rrd_protocol.now () in
	Ds.ds_make ~name:"current_time"
		~description:"The current time"
		~value:(Rrd.VT_Int64 current_time) ~ty:(Rrd.Gauge)
		~default:true ~units:"seconds" (), Rrd.Host

let generate_random_int_data_source () =
	Ds.ds_make ~name:"random_int"
		~description:"A random integer"
		~value:(Rrd.VT_Int64 (Random.int64 256L)) ~ty:(Rrd.Absolute)
		~default:true ~units:"things" (), Rrd.SR "my_sr"

let generate_random_float_data_source () =
	Ds.ds_make ~name:"random_float"
		~description:"A random float"
		~value:(Rrd.VT_Float (Random.float 1.0)) ~ty:(Rrd.Absolute)
		~default:true ~units:"bits of things" (), Rrd.VM "my_vm"

let generate_data_sources () =
	let include_extra_data_sources = get_extra_data_sources_flag () in
	[generate_time_data_source ()] @
	if include_extra_data_sources
	then [
		generate_random_int_data_source ();
		generate_random_float_data_source ();
	]
	else []

let generate_payload () = {
	timestamp = Rrd_protocol.now ();
	datasources = generate_data_sources ();
}

let main_loop writer interval =
	Sys.set_signal Sys.sigint
		(Sys.Signal_handle (fun _ -> writer.Rrd_writer.cleanup (); exit 0));
	try
		while true do
			writer.Rrd_writer.write_payload (generate_payload ());
			Thread.delay interval
		done
	with e ->
		writer.Rrd_writer.cleanup ();
		raise e

let protocol_of_string = function
	| "v1" -> (module Rrd_protocol_v1 : PROTOCOL)
	| "v2" -> (module Rrd_protocol_v2 : PROTOCOL)
	| _ -> failwith "Unknown protocol"

let write_file path protocol =
	Random.self_init ();
	let module Protocol = (val protocol_of_string protocol : PROTOCOL) in
	let module Writer = Rrd_writer.FileWriter(Protocol) in
	let writer = Writer.create path in
	main_loop writer 5.0

let write_page domid protocol =
	Random.self_init ();
	let module Protocol = (val protocol_of_string protocol : PROTOCOL) in
	let module Writer = Rrd_writer.PageWriter(Protocol) in
	let writer = Writer.create (domid, 1) in
	main_loop writer 5.0