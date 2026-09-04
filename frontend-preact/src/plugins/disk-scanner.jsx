import { useEffect, useRef, useState } from 'preact/hooks';
import { sx } from '../stylex-styles.js';

const diskVolumes = [
  {
    id: 'main',
    name: 'Main drive',
    path: '/',
    used: '714 GB',
    total: '1 TB',
    percent: 71
  },
  {
    id: 'archive',
    name: 'Archive',
    path: '/mnt/archive',
    used: '1.8 TB',
    total: '4 TB',
    percent: 45
  },
  {
    id: 'backup',
    name: 'Backup disk',
    path: '/mnt/backup',
    used: '286 GB',
    total: '500 GB',
    percent: 57
  }
];

const diskFolders = [
  { name: 'Projects', size: '182.4 GB', percent: 83 },
  { name: 'Media', size: '96.8 GB', percent: 58 },
  { name: 'Applications', size: '74.2 GB', percent: 42 },
  { name: 'System', size: '38.6 GB', percent: 25 }
];

export function DiskScanner() {
  const [selectedVolumeId, setSelectedVolumeId] = useState('main');
  const [diskScanState, setDiskScanState] = useState('idle');
  const [diskScanProgress, setDiskScanProgress] = useState(0);
  const timerRef = useRef(null);
  const selectedVolume = diskVolumes.find(
    (volume) => volume.id === selectedVolumeId
  );

  useEffect(
    () => () => {
      if (timerRef.current) clearInterval(timerRef.current);
    },
    []
  );

  function startDiskScan() {
    if (diskScanState === 'scanning') return;
    setDiskScanState('scanning');
    setDiskScanProgress(0);
    let progress = 0;
    if (timerRef.current) clearInterval(timerRef.current);
    timerRef.current = setInterval(() => {
      progress += 20;
      setDiskScanProgress(progress);
      if (progress >= 100) {
        clearInterval(timerRef.current);
        timerRef.current = null;
        setDiskScanState('complete');
      }
    }, 140);
  }

  return (
    <section className={sx('tool-page')}>
      <div className={sx('tool-heading')}>
        <div>
          <p className={sx('eyebrow')}>Storage</p>
          <h1 className={sx('pageTitle')}>Disk Scanner</h1>
          <p className={sx('lede')}>Check usage, then scan a volume.</p>
        </div>
        <span className={sx('mock-badge')}>Mock</span>
      </div>

      <div className={sx('disk-grid')}>
        <div className={sx('tool-panel')}>
          <div className={sx('panel-heading')}>
            <div>
              <span className={sx('panel-label')}>Target</span>
              <h2 className={sx('panel-title')}>Volume</h2>
            </div>
            <span className={sx('panel-status')}>
              {diskScanState === 'complete' ? 'Done' : 'Ready'}
            </span>
          </div>
          <label className={sx('select-label')} htmlFor="volume-select">
            Volume
          </label>
          <select
            className={sx('select')}
            id="volume-select"
            value={selectedVolumeId}
            onChange={(event) => setSelectedVolumeId(event.currentTarget.value)}
            disabled={diskScanState === 'scanning'}
          >
            {diskVolumes.map((volume) => (
              <option key={volume.id} value={volume.id}>
                {volume.name} - {volume.path}
              </option>
            ))}
          </select>
          <div className={sx('summaryRow')}>
            <div className={sx('summaryCopy')}>
              <strong>{selectedVolume.used}</strong>
              <span className={sx('muted')}>
                of {selectedVolume.total} used
              </span>
            </div>
            <strong>{selectedVolume.percent}%</strong>
          </div>
          <div className={sx('bar')} role="img" aria-label="Used storage">
            <span
              className={sx('barFill')}
              style={`width: ${selectedVolume.percent}%`}
            />
          </div>
          <button
            type="button"
            className={sx('primary')}
            onClick={startDiskScan}
            disabled={diskScanState === 'scanning'}
          >
            {diskScanState === 'scanning'
              ? `Scanning ${diskScanProgress}%`
              : diskScanState === 'complete'
                ? 'Scan again'
                : 'Start mock scan'}
          </button>
          <p className={sx('note')}>Mock data only. No files are read.</p>
        </div>

        <div className={sx('tool-panel')}>
          <div className={sx('panel-heading')}>
            <div>
              <span className={sx('panel-label')}>Largest</span>
              <h2 className={sx('panel-title')}>Folders</h2>
            </div>
            <span className={sx('muted')}>never</span>
          </div>
          <div className={sx('folder-list')}>
            {diskFolders.map((folder) => (
              <div key={folder.name}>
                <div className={sx('folder-copy')}>
                  <span>{folder.name}</span>
                  <strong className={sx('folderStrong')}>{folder.size}</strong>
                </div>
                <div className={sx('barNoMargin')}>
                  <span
                    className={sx('barFill')}
                    style={`width: ${folder.percent}%`}
                  />
                </div>
              </div>
            ))}
          </div>
          <div className={sx('footerRow')}>
            <span>Free space</span>
            <strong className={sx('strongGreen')}>286 GB</strong>
          </div>
        </div>
      </div>
    </section>
  );
}
