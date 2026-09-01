<script>
  const diskVolumes = [
    { id: "main", name: "Main drive", path: "/", used: "714 GB", total: "1 TB", percent: 71 },
    { id: "archive", name: "Archive", path: "/mnt/archive", used: "1.8 TB", total: "4 TB", percent: 45 },
    { id: "backup", name: "Backup disk", path: "/mnt/backup", used: "286 GB", total: "500 GB", percent: 57 },
  ];

  const diskFolders = [
    { name: "Projects", size: "182.4 GB", percent: 83 },
    { name: "Media", size: "96.8 GB", percent: 58 },
    { name: "Applications", size: "74.2 GB", percent: 42 },
    { name: "System", size: "38.6 GB", percent: 25 },
  ];

  let selectedVolumeId = $state("main");
  let diskScanState = $state("idle");
  let diskScanProgress = $state(0);
  let selectedVolume = $derived(diskVolumes.find((volume) => volume.id === selectedVolumeId));

  function startDiskScan() {
    if (diskScanState === "scanning") return;
    diskScanState = "scanning";
    diskScanProgress = 0;
    let progress = 0;
    const timer = setInterval(() => {
      progress += 20;
      diskScanProgress = progress;
      if (progress >= 100) {
        clearInterval(timer);
        diskScanState = "complete";
      }
    }, 140);
  }
</script>

<section class="tool-page">
  <div class="tool-heading">
    <div>
      <p class="eyebrow">Storage utility / Mock 01</p>
      <h1>Disk Scanner</h1>
      <p>See the shape of your storage before the native scanner starts indexing real files.</p>
    </div>
    <span class="mock-badge">Backend pending</span>
  </div>

  <div class="disk-grid">
    <div class="tool-panel scan-panel">
      <div class="panel-heading">
        <div>
          <span class="panel-label">Scan target</span>
          <h2>Choose a volume</h2>
        </div>
        <span class="panel-status">{diskScanState === "complete" ? "Complete" : "Ready"}</span>
      </div>
      <label class="select-label" for="volume-select">Volume</label>
      <select id="volume-select" bind:value={selectedVolumeId} disabled={diskScanState === "scanning"}>
        {#each diskVolumes as volume}
          <option value={volume.id}>{volume.name} - {volume.path}</option>
        {/each}
      </select>
      <div class="volume-summary">
        <div>
          <strong>{selectedVolume.used}</strong>
          <span>of {selectedVolume.total} used</span>
        </div>
        <strong>{selectedVolume.percent}%</strong>
      </div>
      <div class="progress-track" aria-label="Used storage">
        <span style={`width: ${selectedVolume.percent}%`}></span>
      </div>
      <button class="primary-button" onclick={startDiskScan} disabled={diskScanState === "scanning"}>
        {diskScanState === "scanning" ? `Scanning ${diskScanProgress}%` : diskScanState === "complete" ? "Scan again" : "Start mock scan"}
      </button>
      <p class="panel-note">Mock mode uses representative folders. No files are read or changed.</p>
    </div>

    <div class="tool-panel storage-panel">
      <div class="panel-heading">
        <div>
          <span class="panel-label">Storage map</span>
          <h2>Largest areas</h2>
        </div>
        <span class="scan-time">Last scan: never</span>
      </div>
      <div class="folder-list">
        {#each diskFolders as folder}
          <div class="folder-row">
            <div class="folder-copy">
              <span>{folder.name}</span>
              <strong>{folder.size}</strong>
            </div>
            <div class="folder-track"><span style={`width: ${folder.percent}%`}></span></div>
          </div>
        {/each}
      </div>
      <div class="storage-footer"><span>Free space</span><strong>286 GB</strong></div>
    </div>
  </div>
</section>
