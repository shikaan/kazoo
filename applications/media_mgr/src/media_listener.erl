%%%-------------------------------------------------------------------
%%% @copyright (C) 2012-2017, 2600Hz INC
%%% @doc
%%%
%%% @end
%%% @contributors
%%%   James Aimonetti
%%%   Karl Anderson
%%%-------------------------------------------------------------------
-module(media_listener).
-behaviour(gen_listener).

%% API
-export([start_link/0
        ,handle_media_req/2
        ]).

%% gen_server callbacks
-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,handle_event/2
        ,terminate/2
        ,code_change/3
        ]).

-include("media.hrl").

-record(state, {}).
-type state() :: #state{}.

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc Starts the server
%%--------------------------------------------------------------------
-spec start_link() -> startlink_ret().
start_link() ->
    gen_listener:start_link(?SERVER, [{'bindings', [{'media', []}]}
                                     ,{'responders', [{{?MODULE, 'handle_media_req'}
                                                      ,[{<<"media">>, <<"media_req">>}]}
                                                     ]}
                                     ], []).

-spec handle_media_req(kz_json:object(), kz_proplist()) -> kz_amqp_worker:cast_return().
handle_media_req(JObj, _Props) ->
    'true' = kapi_media:req_v(JObj),
    _ = kz_util:put_callid(JObj),
    lager:debug("recv media req for msg id: ~s", [kz_api:msg_id(JObj)]),
    MediaName = kz_json:get_value(<<"Media-Name">>, JObj),
    case kz_media_url:playback(MediaName, JObj) of
        {'error', ErrorMessage} -> send_error_resp(JObj, ErrorMessage);
        StreamURL -> send_media_resp(JObj, StreamURL)
    end.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec init([]) -> {'ok', state()}.
init([]) ->
    lager:debug("starting media_mgr listener"),
    {'ok', #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec handle_call(any(), pid_ref(), state()) -> handle_call_ret_state(state()).
handle_call(_Request, _From, State) ->
    {'reply', {'error', 'not_supported'}, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(any(), state()) -> handle_cast_ret_state(state()).
handle_cast(_Msg, State) ->
    {'noreply', State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec handle_info(any(), state()) -> handle_info_ret_state(state()).
handle_info(_Info, State) ->
    {'noreply', State}.

-spec handle_event(kz_json:object(), state()) -> gen_listener:handle_event_return().
handle_event(_JObj, _State) ->
    {'reply', []}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _State) ->
    lager:debug("media listener terminating: ~p", [_Reason]).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec send_error_resp(kz_json:object(), atom() | ne_binary()) ->
                             kz_amqp_worker:cast_return().
send_error_resp(JObj, ErrMsg) ->
    MediaName = kz_json:get_value(<<"Media-Name">>, JObj),
    Error = [{<<"Media-Name">>, MediaName}
            ,{<<"Error-Code">>, <<"other">>}
            ,{<<"Error-Msg">>, kz_term:to_binary(ErrMsg)}
            ,{<<"Msg-ID">>, kz_json:get_value(<<"Msg-ID">>, JObj)}
             | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
            ],
    lager:debug("sending error reply ~s for ~s", [ErrMsg, MediaName]),
    ServerId = kz_json:get_value(<<"Server-ID">>, JObj),
    Publisher = fun(P) -> kapi_media:publish_error(ServerId, P) end,
    kz_amqp_worker:cast(Error, Publisher).

-spec send_media_resp(kz_json:object(), ne_binary()) ->
                             kz_amqp_worker:cast_return().
send_media_resp(JObj, StreamURL) ->
    lager:debug("media stream URL: ~s", [StreamURL]),
    Resp = [{<<"Media-Name">>, kz_json:get_value(<<"Media-Name">>, JObj)}
           ,{<<"Stream-URL">>, StreamURL}
           ,{<<"Msg-ID">>, kz_json:get_value(<<"Msg-ID">>, JObj)}
            | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
           ],
    ServerId = kz_json:get_value(<<"Server-ID">>, JObj),
    Publisher = fun(P) -> kapi_media:publish_resp(ServerId, P) end,
    kz_amqp_worker:cast(Resp, Publisher).
