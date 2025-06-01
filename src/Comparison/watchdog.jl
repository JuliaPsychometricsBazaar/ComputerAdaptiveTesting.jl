using Base.Threads: nthreads


abstract type AbstractWatchdogTask end

mutable struct WatchdogTask <: AbstractWatchdogTask
    timeout::Float64
    channel::Channel
    task::Union{Task, Nothing}
end

function run_watchdog(timeout, channel, worker_task)
    #Core.println("Starting watchdog")
    #Base.flush(stdout)
    reset_timestamp = time()
    deadline = reset_timestamp + timeout
    msg = nothing
    active = false
    die = false
    #Core.println("X")
    #Base.flush(stdout)
    l = ReentrantLock()
    #Core.println("Y")
    #Base.flush(stdout)
    activation = Threads.Condition(l)
    #Core.println("Blam")
    #Base.flush(stdout)
    @async begin
        #Core.println("Subloop")
        while true
            cmd = take!(channel)
            #Core.println("Take")
            if haskey(cmd, :kill)
                die = true
                lock(l) do
                    notify(activation)
                end
                break
            end
            lock(l) do
                if haskey(cmd, :reset_timestamp)
                    reset_timestamp = cmd[:reset_timestamp]
                    deadline = reset_timestamp + timeout
                end
                if haskey(cmd, :msg)
                    msg = cmd[:msg]
                end
                if haskey(cmd, :active)
                    active = cmd[:active]
                    if active
                        #Core.println("Notify")
                        notify(activation)
                    end
                end
            end
        end
    end
    loop = true
    while loop
        #Core.println("Aquiring lock")
        loop = lock(l) do
            while !active && !die
                #Core.println("Waiting for activation")
                wait(activation)
            end
            if die
                return false
            end
            if active
                unlock(l)
                try
                    delay = deadline - time()
                    #Core.println("Sleeping for $delay")
                    sleep(max(delay, 0.0))
                finally
                    lock(l)
                end
            end
            if die
                return false
            end
            overrun = time() - deadline
            if overrun > 0  && active
                msg = "WATCHDOG TIMEOUT: $msg timed after after $(timeout)s (overran $(overrun)s)"
                unlock(l)
                put!(channel, (; kill=true))
                Core.println("")
                Core.println(msg)
                Core.println("")
                Base.flush(Core.stdout)
                sleep(0.1)
                schedule(worker_task, InterruptException(), error=true)
                # Wait a proper amount of time here since otherwise we will probably not get a stacktrace
                sleep(5.0)
                if istaskdone(worker_task)
                    return false
                end
                ccall(:uv_kill, Cint, (Cint, Cint), getpid(), Base.SIGTERM)
                sleep(1.0)
                ccall(:uv_kill, Cint, (Cint, Cint), getpid(), Base.SIGKILL)
                sleep(1.0)
                exit(1) # This is done last since it doesn't always take down the parent
            end
            return true
        end
    end
end

function WatchdogTask(timeout::Float64)
    if timeout !== Inf
        channel = Channel{Any}(Inf)
        WatchdogTask(timeout, channel, nothing)
    else
        NullWatchdog()
    end
    #WatchdogTask(task, timeout, channel, nothing)
end

function start!(f, watchdog::WatchdogTask)
    if nthreads(:interactive) < 1 || nthreads(:default) < 1
        error("WatchdogTask: Need an interactive and default thread")
    end
    worker_task = Threads.@spawn :default f()
    watchdog.task = Threads.@spawn :interactive run_watchdog(watchdog.timeout, watchdog.channel, worker_task)
    wait(worker_task)
    put!(watchdog.channel, (; kill=true))
    wait(watchdog.task)
end

function reset!(watchdog::WatchdogTask, msg=nothing)
    if istaskdone(watchdog.task)
        wait(watchdog.task)
    end
    payload = (;
        active=true,
        reset_timestamp=time(),
    )
    if msg !== nothing
        payload = (; payload..., msg=msg)
    end
    #@info "Put" payload
    put!(watchdog.channel, payload)
end

function deactivate!(watchdog::WatchdogTask)
    if istaskdone(watchdog.task)
        wait(watchdog.task)
    end
    put(watchdog.channel, (; active=false))
end

struct NullWatchdog <: AbstractWatchdogTask end
function reset!(::NullWatchdog, msg=nothing) end
function deactivate!(::NullWatchdog) end