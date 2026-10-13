using Awake.Core;
using Xunit;
namespace Awake.Core.Tests;
public class RecoveryTests
{
    sealed class Store : IRecoveryStore
    {
        public LidRecoveryRecord? Record; public bool FailSave,FailClear;
        public LidRecoveryRecord? Load()=>Record;
        public void Save(LidRecoveryRecord record) {if(FailSave)throw new IOException("save");Record=record;}
        public void Clear(){if(FailClear)throw new IOException("clear");Record=null;}
    }
    sealed class Backend(Store store) : ILidSettingsBackend
    {
        public LidSetting Setting=new(Guid.NewGuid(),1,2); public bool FailWrite; public int Writes;
        public LidSetting Read()=>Setting;
        public void Write(LidSetting setting){Assert.NotNull(store.Record); Writes++;if(FailWrite)throw new IOException("write");Setting=setting;}
    }
    [Fact] public void JournalPrecedesMutationAndFreshProcessRestores()
    {
        var store=new Store();var backend=new Backend(store);var baseline=backend.Setting;
        new LidRecoveryCoordinator(backend,store).Begin(DateTimeOffset.UnixEpoch); Assert.Equal(0,backend.Setting.AcAction);Assert.Equal(2,backend.Setting.DcAction);
        var restarted=new LidRecoveryCoordinator(backend,store);restarted.Restore();Assert.Equal(baseline,backend.Setting);Assert.Null(store.Record);
    }
    [Fact] public void SaveFailureDoesNotMutateSystem()
    {
        var store=new Store {FailSave=true};var backend=new Backend(store);Assert.Throws<IOException>(()=>new LidRecoveryCoordinator(backend,store).Begin(DateTimeOffset.UnixEpoch));Assert.Equal(0,backend.Writes);
    }
    [Fact] public void RecoveryFailureRetainsJournalForRetry()
    {
        var store=new Store();var backend=new Backend(store);var recovery=new LidRecoveryCoordinator(backend,store);recovery.Begin(DateTimeOffset.UnixEpoch);backend.FailWrite=true;
        Assert.Throws<IOException>(recovery.Restore);Assert.True(recovery.NeedsRecovery);Assert.NotNull(store.Record);backend.FailWrite=false;recovery.Restore();Assert.False(recovery.NeedsRecovery);
    }
    [Fact] public void ChangedPlanOrExternalSettingsAreNeverOverwritten()
    {
        var store=new Store();var backend=new Backend(store);var recovery=new LidRecoveryCoordinator(backend,store);recovery.Begin(DateTimeOffset.UnixEpoch);
        var owned=backend.Setting;backend.Setting=owned with {Scheme=Guid.NewGuid()};Assert.Throws<InvalidOperationException>(recovery.Restore);Assert.Equal(1,backend.Writes);Assert.NotNull(store.Record);
        backend.Setting=owned with {DcAction=3};Assert.Throws<InvalidOperationException>(recovery.Restore);Assert.Equal(1,backend.Writes);
        backend.Setting=owned;recovery.Restore();Assert.Null(store.Record);
    }
    [Fact] public void ClearFailureRetriesWithoutReapplyingSettings()
    {
        var store=new Store();var backend=new Backend(store);var recovery=new LidRecoveryCoordinator(backend,store);recovery.Begin(DateTimeOffset.UnixEpoch);store.FailClear=true;
        Assert.Throws<IOException>(recovery.Restore);Assert.Equal(2,backend.Writes);store.FailClear=false;recovery.Restore();Assert.Equal(2,backend.Writes);
    }
    [Fact] public void ExistingDisabledSettingIsConflict()
    {
        var store=new Store();var backend=new Backend(store);backend.Setting=backend.Setting with {AcAction=0};Assert.Throws<InvalidOperationException>(()=>new LidRecoveryCoordinator(backend,store).Begin(DateTimeOffset.UnixEpoch));Assert.Null(store.Record);
    }
    [Fact] public void IndependentHeartbeatEndsInfiniteLeaseAndLateRenewNeverRevives()
    {
        var store=new Store();var backend=new Backend(store);var recovery=new LidRecoveryCoordinator(backend,store);var lease=new LeaseEngine(recovery,SessionTests.Supported);var owner=Guid.NewGuid();
        var id=lease.Acquire(owner,SessionTests.Options(0) with {LidMode=true},SessionTests.Good,SessionTests.Clock());
        Assert.Throws<InvalidOperationException>(()=>lease.Renew(id,owner,SessionTests.Good,SessionTests.Clock(20)));Assert.False(lease.IsActive);Assert.Equal(StopReason.HeartbeatLost,lease.LastStopReason);Assert.Null(store.Record);
    }
    [Fact] public void LeaseChecksOwnerAndRecoversAfterClientLoss()
    {
        var store=new Store();var backend=new Backend(store);var lease=new LeaseEngine(new(backend,store),SessionTests.Supported);var owner=Guid.NewGuid();var id=lease.Acquire(owner,SessionTests.Options() with {LidMode=true},SessionTests.Good,SessionTests.Clock());
        Assert.Throws<InvalidOperationException>(()=>lease.Release(id,Guid.NewGuid()));Assert.True(lease.IsActive);lease.Disconnected(owner);Assert.False(lease.IsActive);Assert.Equal(StopReason.Disconnected,lease.LastStopReason);
    }
    [Fact] public void HeartbeatRestoreFailureEndsLeaseButRetainsDurableRecovery()
    {
        var store=new Store();var backend=new Backend(store);var recovery=new LidRecoveryCoordinator(backend,store);var lease=new LeaseEngine(recovery,SessionTests.Supported);
        lease.Acquire(Guid.NewGuid(),SessionTests.Options(0) with {LidMode=true},SessionTests.Good,SessionTests.Clock());backend.FailWrite=true;
        lease.Tick(SessionTests.Good,SessionTests.Clock(20));Assert.False(lease.IsActive);Assert.True(lease.NeedsRecovery);Assert.Equal(StopReason.HeartbeatLost,lease.LastStopReason);Assert.NotNull(store.Record);
        backend.FailWrite=false;lease.Tick(SessionTests.Good,SessionTests.Clock(21));Assert.False(lease.NeedsRecovery);Assert.Null(store.Record);
    }

}
