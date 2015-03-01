-module(mod_auto_muc).

-behavior(gen_mod).

-include("ejabberd.hrl").
-include("logger.hrl").
-include("jlib.hrl").

-record(private_storage,
        {usns = {<<"">>, <<"">>, <<"">>} :: {binary(), binary(), binary() |
                                             '$1' | '_'},
         xml = #xmlel{} :: xmlel() | '_' | '$1'}).

-export([start/2, stop/1, on_user_register/2, add_children/3, add_children/4]).

start(Host, _Opts) ->
    ejabberd_hooks:add(register_user, Host, ?MODULE, on_user_register, 50),
    ok.

stop(Host) ->
    ejabberd_hooks:delete(register_user, Host, ?MODULE, on_user_register, 50),
    ok.

on_user_register(User, Server) ->
	AutoMuc = gen_mod:get_module_opt(Server, ?MODULE, muc, fun(A) when is_list(A) -> A end, none),
	XmlNS = <<"storage:bookmarks">>,
    Xmlch = add_children(length(AutoMuc), AutoMuc, User),
	Xmlel = #xmlel{name = <<"storage">>,
		    attrs = [{<<"xmlns">>, <<"storage:bookmarks">>}],
		    children = Xmlch},
	?CRITICAL_MSG("~p", [Xmlel]),
	Tr = fun() -> mnesia:write(#private_storage{usns = {User, Server, XmlNS}, xml = Xmlel}) end,
	mnesia:activity(transaction, Tr),
    ok.

add_children(Lengt, AutoMuc, User)
	when Lengt > 0 ->
		Room = lists:nth(Lengt, AutoMuc),
		RoomName = element(2, jlib:string_to_jid(Room)),
		Elem = [#xmlel{name = <<"conference">>, 
			   attrs = [{<<"minimize">>,<<"0">>}, {<<"jid">>, Room}, {<<"autojoin">>, <<"1">>}, {<<"name">>, RoomName}],
			   children = [#xmlel{name = <<"nick">>, children = [{xmlcdata, User}]}]}],
		add_children(Lengt-1, AutoMuc, User, Elem).
add_children(Lengt, AutoMuc, User, Xmlch)
	when Lengt > 0 ->
		Room = lists:nth(Lengt, AutoMuc),
		RoomName = element(2, jlib:string_to_jid(Room)),
		Elem = [#xmlel{name = <<"conference">>, 
			   attrs = [{<<"minimize">>,<<"0">>}, {<<"jid">>, Room}, {<<"autojoin">>, <<"1">>}, {<<"name">>, RoomName}],
			   children = [#xmlel{name = <<"nick">>, children = [{xmlcdata, User}]}]}],
		add_children(Lengt-1, AutoMuc, User, lists:append(Xmlch, Elem));
add_children(Lengt, _AutoMuc, _User, Xmlch)
	when Lengt == 0 ->
		Xmlch.
