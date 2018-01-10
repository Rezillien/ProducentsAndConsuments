-module(prodcons).
-compile(export_all).

main() ->
  ConsStartBuf = spawn(fun() -> bufferStartInit() end),
  ProdStartBuf = spawn(fun() -> bufferStartInit() end),
  ConsEndBuf = spawn(fun() -> bufferEnd(ConsStartBuf,1,0) end),
  ProdEndBuf = spawn(fun() -> bufferEnd(ProdStartBuf,1,0) end),
  createBuffer(10,ProdStartBuf,ProdEndBuf,ConsStartBuf,ConsEndBuf),
  sendProduce(2,ProdEndBuf),
  sendConsume(4,ConsEndBuf).

sendProduce(N,Prod) ->
  Prod ! [num, N].

sendConsume(N,Cons) ->
  Cons ! [num, N].

createBuffer(N,ProdStart,ProdEnd,ConsStart,ConsEnd) ->
  spawn(fun() -> bufferPart(ProdStart,ProdEnd,ConsStart,ConsEnd,0) end),
  if
    N > 0 ->
      createBuffer(N-1,ProdStart,ProdEnd,ConsStart,ConsEnd);
    true ->
      io:format("creater~n")
  end.

bufferStartInit() ->
  receive
    [pid, Pid] ->
      bufferStart(Pid)
  end.

bufferStart(StartPid) ->
  receive
    [num,N] ->
      StartPid ! [num, N],
      receive
        [pid,Pid] ->
          bufferStart(Pid)
      end
  end.

bufferEnd(StartPid,N,PPid) ->
  receive
    [num, M] ->
      if
        N > M ->
          StartPid ! [num,M],
          bufferEnd(StartPid,N-M,PPid);
        true ->
          waitFor(StartPid,N-M+1,N,PPid),
          StartPid ! [num,M],
          bufferEnd(StartPid,1,PPid)
      end;
    [queueRequest, Pid] ->
      if
        N == 1 ->
          Pid ! [queue,N],
          bufferEnd(StartPid,N+1,Pid);
        true ->
          Pid ! [queue,N],
          PPid ! [pid,Pid],
          bufferEnd(StartPid,N+1,Pid)
      end
  end.

waitFor(StartPid,M,N,PPid) ->
  if
    M > 0 ->
      receive
        [queueRequest, Pid] ->
          if
            N == 1 ->
              Pid ! [queue,N],
              waitFor(StartPid,M-1,N+1,Pid);
            true ->
              Pid ! [queue,N],
              PPid ! [pid,Pid],
              waitFor(StartPid,M-1,N+1,Pid)
          end
      end;
    true ->
      ok
  end.




  

bufferPart(ProdStart, ProdEnd, ConsStart, ConsEnd, N) ->
  if
    N==0 ->
      ProdEnd ! [queueRequest, self()],
      receive
        [queue, M] ->
          if
            M == 1 ->
              ProdStart ! [pid, self()];
            true ->
              ok
          end,
          receive
            [pid, Pid] ->
              receive
                [num, K] ->
                  if
                    M-K>0 ->
                      Pid ! [num, K],
                      bufferPart2(ProdStart,ProdEnd,ConsStart,ConsEnd,N,M-K,Pid);
                    true ->
                      Pid ! [num, K],
                      work(N),
                      bufferPart(ProdStart,ProdEnd,ConsStart,ConsEnd,1)
                  end
              end;
            [num, K] ->
              work(N),
              bufferPart(ProdStart,ProdEnd,ConsStart,ConsEnd,1)
          end
      end;
    N==1 ->
      ConsEnd ! [queueRequest, self()],
      receive
        [queue, M] ->
          if
            M == 1 ->
              ConsStart ! [pid, self()];
            true ->
              ok
          end,
          receive
            [pid, Pid] ->
              receive
                [num, K] ->
                  if
                    M-K>0 ->
                      Pid ! [num, K],
                      bufferPart2(ProdStart,ProdEnd,ConsStart,ConsEnd,N,M-K,Pid);
                    true ->
                      Pid ! [num, K],
                      work(N),
                      bufferPart(ProdStart,ProdEnd,ConsStart,ConsEnd,0)
                  end
              end;
            [num, K] ->
              work(N),
              bufferPart(ProdStart,ProdEnd,ConsStart,ConsEnd,0)
          end
      end
  end.

bufferPart2(ProdStart,ProdEnd,ConsStart,ConsEnd,N,M,PidNext)->
  if
    N == 0 ->
      if
        M == 1 ->
          ProdStart ! [pid, self()];
        true ->
          ok
      end,
      receive
        [num, K] ->
          if
            M-K>0 ->
              PidNext ! [num, K],
              bufferPart2(ProdStart,ProdEnd,ConsStart,ConsEnd,N,M-K,PidNext);
            true ->
              PidNext ! [num, K],
              work(N),
              bufferPart(ProdStart,ProdEnd,ConsStart,ConsEnd,1)
            end
      end;
    N == 1 ->
      if
        M == 1 ->
          ConsStart ! [pid, self()];
        true ->
          ok
      end,
      receive
        [num, K] ->
          if
            M-K>0 ->
              PidNext ! [num, K],
              bufferPart2(ProdStart,ProdEnd,ConsStart,ConsEnd,N,M-K,PidNext);
            true ->
              PidNext ! [num, K],
              work(N),
              bufferPart(ProdStart,ProdEnd,ConsStart,ConsEnd,0)
          end
      end
  end.


work(N)->
  io:format("work~p~n",[N]).


