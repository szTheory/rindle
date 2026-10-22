"""POSIX process groups owned by one readiness command; never select foreign PIDs."""
import os
import signal
import subprocess


def kill_owned(child):
    if child is not None and child.poll() is None:
        try:os.killpg(child.pid,signal.SIGKILL)
        except ProcessLookupError:pass
        child.wait()


def stop_owned(child,grace=5):
    if child is not None and child.poll() is None:
        try:os.killpg(child.pid,signal.SIGTERM)
        except ProcessLookupError:pass
        try:child.wait(timeout=grace)
        except subprocess.TimeoutExpired:kill_owned(child)


def popen_owned(*args,**kwargs):
    # Deliver an interrupt only once the new group is registered locally. If it
    # arrives during spawn, this helper kills the new group before propagating it.
    mask=signal.pthread_sigmask(signal.SIG_BLOCK,{signal.SIGINT,signal.SIGTERM})
    child=None
    try:
        kwargs['start_new_session']=True
        # These CLI owners are single-threaded. Reset the inherited mask in the
        # child before exec so its own SIGTERM handler can stop nested groups.
        kwargs['preexec_fn']=lambda:signal.pthread_sigmask(signal.SIG_SETMASK,mask)
        child=subprocess.Popen(*args,**kwargs)
        signal.pthread_sigmask(signal.SIG_SETMASK,mask)
        return child
    except BaseException:
        kill_owned(child)
        raise
    finally:signal.pthread_sigmask(signal.SIG_SETMASK,mask)
