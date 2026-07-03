import { WordCard } from '../model/WordCard';
import { Theme, categoryOf } from '../common/Theme';

/**
 * 轨迹画布 — 当日识词点位的「概览式」呈现：
 * 只显示大概的点位与淡色路径，不显示精准街道坐标（隐私可感知）。
 * 进入页面时点位按时间顺序依次点亮，再用平滑曲线串联成一天的足迹。
 */
@ComponentV2
export struct TrackCanvas {
  @Require @Param words: WordCard[];
  /** 点位被点击时回调（弹出对应贴纸详情） */
  @Event onPick: (card: WordCard) => void = (card: WordCard) => {
  };

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private timer: number = -1;
  private progress: number = 0;
  private pointsX: number[] = [];
  private pointsY: number[] = [];

  @Monitor('words')
  onWordsChange(): void {
    this.restart();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** 由 id 派生稳定伪随机点位：同一天的轨迹每次进入都长一个样 */
  private layoutPoints(): void {
    this.pointsX = [];
    this.pointsY = [];
    const w = this.ctx.width;
    const h = this.ctx.height;
    const marginX = 36;
    const marginY = 30;
    const n = this.words.length;
    for (let i = 0; i < n; i++) {
      const id = this.words[i].id;
      let hash = 7;
      for (let c = 0; c < id.length; c++) {
        hash = (hash * 31 + id.charCodeAt(c)) % 100000;
      }
      // x 按时间序从左到右推进，y 用哈希抖动，看起来像一条散步路线
      const baseX = n === 1 ? w / 2 : marginX + (w - marginX * 2) * i / (n - 1);
      const jitterY = marginY + (hash % 1000) / 1000 * (h - marginY * 2);
      this.pointsX.push(baseX);
      this.pointsY.push(jitterY);
    }
  }

  private restart(): void {
    this.stopTimer();
    this.progress = 0;
    if (this.ctx.width <= 0) {
      return;
    }
    this.layoutPoints();
    if (this.words.length === 0) {
      this.drawEmpty();
      return;
    }
    this.timer = setInterval(() => {
      this.progress += 0.025;
      if (this.progress >= 1) {
        this.progress = 1;
        this.stopTimer();
      }
      this.draw();
    }, 30);
  }

  private drawEmpty(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    this.ctx.clearRect(0, 0, w, h);
    this.ctx.fillStyle = Theme.TEXT_SUB;
    this.ctx.font = '13vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('这一天还没有足迹', w / 2, h / 2);
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    this.ctx.clearRect(0, 0, w, h);
    const n = this.words.length;
    const visible = Math.max(1, Math.ceil(this.progress * n));

    // 淡色路径：相邻点位间用中点二次贝塞尔连成柔和曲线
    if (visible > 1) {
      this.ctx.strokeStyle = Theme.TRACK;
      this.ctx.lineWidth = 2;
      this.ctx.setLineDash([6, 5]);
      this.ctx.beginPath();
      this.ctx.moveTo(this.pointsX[0], this.pointsY[0]);
      for (let i = 1; i < visible; i++) {
        const mx = (this.pointsX[i - 1] + this.pointsX[i]) / 2;
        const my = (this.pointsY[i - 1] + this.pointsY[i]) / 2;
        this.ctx.quadraticCurveTo(this.pointsX[i - 1], this.pointsY[i - 1], mx, my);
      }
      this.ctx.lineTo(this.pointsX[visible - 1], this.pointsY[visible - 1]);
      this.ctx.stroke();
      this.ctx.setLineDash([]);
    }

    // 点位贴纸：白边圆点 + 分类色内芯，保持贴纸语言的统一
    for (let i = 0; i < visible; i++) {
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.beginPath();
      this.ctx.arc(this.pointsX[i], this.pointsY[i], 10, 0, Math.PI * 2);
      this.ctx.fill();
      this.ctx.fillStyle = categoryOf(this.words[i].category).accent;
      this.ctx.beginPath();
      this.ctx.arc(this.pointsX[i], this.pointsY[i], 6, 0, Math.PI * 2);
      this.ctx.fill();
    }

    // 地点标签只标首尾，克制不喧宾
    this.ctx.fillStyle = Theme.TEXT_SUB;
    this.ctx.font = '11vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(this.words[0].place, this.pointsX[0], this.pointsY[0] - 16);
    if (visible === n && n > 1) {
      this.ctx.fillText(this.words[n - 1].place, this.pointsX[n - 1], this.pointsY[n - 1] - 16);
    }
  }

  private pickAt(x: number, y: number): void {
    for (let i = 0; i < this.words.length; i++) {
      const dx = x - this.pointsX[i];
      const dy = y - this.pointsY[i];
      if (dx * dx + dy * dy <= 24 * 24) {
        this.onPick(this.words[i]);
        return;
      }
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.restart();
      })
      .onClick((event: ClickEvent) => {
        this.pickAt(event.x, event.y);
      })
  }
}
