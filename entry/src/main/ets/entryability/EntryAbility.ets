import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DataStore } from '../services/DataStore';
import { LocalModelService } from '../services/LocalModelService';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0001, TAG, 'onCreate');
    // 数据仓库随 Ability 初始化，UI 加载前词汇已就绪
    DataStore.get().init(this.context);
    // 端侧模型自检（异步，不阻塞启动）：hilog 搜 SELFTEST 即知模型在本设备是否可用
    LocalModelService.selfTest(this.context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0001, TAG, `loadContent failed: ${err.code}`);
        return;
      }
      // 相机取景需要沉浸式全屏，最大限度释放取景空间
      try {
        const mainWindow = windowStage.getMainWindowSync();
        mainWindow.setWindowLayoutFullScreen(true);
      } catch (e) {
        hilog.warn(0x0001, TAG, `fullscreen failed: ${JSON.stringify(e)}`);
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0001, TAG, 'onWindowStageDestroy');
  }

  onDestroy(): void {
    hilog.info(0x0001, TAG, 'onDestroy');
  }
}
