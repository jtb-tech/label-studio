import { inject, observer } from 'mobx-react';
import { FC } from 'react';
import { Block, Elem } from '../../../utils/bem';
import { FF_DEV_2290, isFF } from '../../../utils/feature-flags';
import { Comments as CommentsComponent } from '../../Comments/Comments';
import { AnnotationHistory } from '../../CurrentEntity/AnnotationHistory';
import { PanelBase, PanelProps } from '../PanelBase';
import './DetailsPanel.styl';
import { RegionDetailsMain, RegionDetailsMeta } from './RegionDetails';
import { RegionItem } from './RegionItem';
import { Relations as RelationsComponent } from './Relations';
// eslint-disable-next-line
// @ts-ignore
import { DraftPanel } from '../../DraftPanel/DraftPanel';
interface DetailsPanelProps extends PanelProps {
  regions: any;
  selection: any;
}

const DetailsPanelComponent: FC<DetailsPanelProps> = ({ currentEntity, regions, ...props }) => {
  const selectedRegions = regions.selection;

  return (
    <PanelBase {...props} currentEntity={currentEntity} name="details" title="Details">
      <Content selection={selectedRegions} currentEntity={currentEntity} />
    </PanelBase>
  );
};

const DetailsComponent: FC<DetailsPanelProps> = ({ currentEntity, regions }) => {
  const selectedRegions = regions.selection;

  return (
    <Block name="details-tab">
      <Content selection={selectedRegions} currentEntity={currentEntity} />
    </Block>
  );
};


const Content: FC<any> = observer(({
  selection,
  currentEntity,
}) => {
  return (
    <>
      {(selection.size) ? (
        <RegionsPanel regions={selection}/>
      ) : (
        <GeneralPanel currentEntity={currentEntity}/>
      )}
    </>
  );
});


const CommentsTab: FC<any> = inject('store')(observer(({ store }) => {
  return (
    <>
      {store.hasInterface('annotations:comments') && store.commentStore.isCommentable && (
        <Block name="comments-panel">
          <Elem name="section-tab">
            <Elem name="section-content">
              <CommentsComponent annotationStore={store.annotationStore} commentStore={store.commentStore} cacheKey={`task.${store.task.id}`} />
            </Elem>
          </Elem>
        </Block>
      )}
    </>
  );
}));

const RelationsTab: FC<any> = inject('store')(observer(({ currentEntity }) => {
  const { relationStore } = currentEntity;

  return (
    <>
      <Block name="relations">
        <Elem name="section-tab">
          <Elem name="section-head">Relations ({relationStore.size})</Elem>
          <Elem name="section-content">
            <RelationsComponent relationStore={relationStore} />
          </Elem>
        </Elem>
      </Block>
    </>
  );
}));

const HistoryTab: FC<any> = inject('store')(observer(({ store, currentEntity }) => {
  const showAnnotationHistory = store.hasInterface('annotations:history');
  const showDraftInHistory = isFF(FF_DEV_2290);

  return (
    <>
      <Block name="history">
        {!showDraftInHistory ? (
          <DraftPanel item={currentEntity} />
        ) : (
          <Elem name="section-tab">
            <Elem name="section-head">
              標註歷史
              <span>#{currentEntity.pk ?? currentEntity.id}</span>
            </Elem>
            <Elem name="section-content">
              <AnnotationHistory inline showDraft={showDraftInHistory} enabled={showAnnotationHistory} />
            </Elem>
          </Elem>
        )}
      </Block>
    </>
  );
}));


/* const InfoTab: FC<any> = inject('store')(
  observer(({ selection }) => {
    return (
      <>
        <Block name="info">
          <Elem name="section-tab">
            <Elem name="section-head">選擇詳情</Elem>
            <RegionsPanel regions={selection}/>
          </Elem>
        </Block>
      </>
    );
  }),
); */

const InfoTab = observer(inject('store')(({ selection, store }) => {
  const handleScreenshot = () => {
    // 獲取當前任務ID
    const currentTaskId = store?.task?.id;
    console.log('🧩 Current Task ID:', currentTaskId);
    
    if (!selection || selection.size === 0) {
      console.warn('⚠️ 沒有選擇的 region');
      return;
    }
    
    // 直接使用第一個 region
    const region = selection.list[0];
    
    console.log('🔬 選中的 region:', { 
      id: region.id,
      type: region.type,
      x: region.x, 
      y: region.y, 
      width: region.width, 
      height: region.height 
    });
    
    // 嘗試從 store 中獲取原始圖像 URL
    const imageUrl = getOriginalImageUrl(store);
    
    if (imageUrl) {
      console.log('✅ 找到原始圖像 URL:', imageUrl);
      
      // 使用原始圖像 URL 來創建和裁剪截圖
      const imgElement = new Image();
      
      // 圖像加載成功時的處理
      imgElement.onload = function() {
        console.log('✅ 圖像加載成功，尺寸:', imgElement.width, 'x', imgElement.height);
        
        // 創建 canvas 來裁剪圖像
        const canvas = document.createElement('canvas');
        
        // 計算裁剪區域
        const sx = imgElement.width * (region.x / 100);
        const sy = imgElement.height * (region.y / 100);
        const sw = imgElement.width * (region.width / 100);
        const sh = imgElement.height * (region.height / 100);
        
        canvas.width = sw;
        canvas.height = sh;
        
        const ctx = canvas.getContext('2d');
        
        // 裁剪圖像
        ctx.drawImage(
          imgElement, 
          sx, sy, sw, sh, // 源區域
          0, 0, sw, sh    // 目標區域
        );
        
        // 獲取截圖的 data URL
        const screenshotUrl = canvas.toDataURL('image/png');
        
        // 顯示截圖結果
        showScreenshot(screenshotUrl, region, {
          method: '原始圖像',
          width: sw,
          height: sh,
          imageUrl: imageUrl
        });
      };
      
      // 圖像加載失敗時的處理
      imgElement.onerror = function() {
        console.error('❌ 原始圖像加載失敗:', imageUrl);
        // 回退到 Konva 方法
        useKonvaMethod();
      };
      
      // 設置跨域屬性 (如果圖像是從不同的域加載的)
      imgElement.crossOrigin = "Anonymous";
      
      // 開始加載圖像
      imgElement.src = imageUrl;
    } else {
      console.warn('❌ 無法找到原始圖像 URL，嘗試 Konva 方法');
      useKonvaMethod();
    }
    
    // Konva 方法作為備選
    function useKonvaMethod() {
      console.log('🎯 嘗試使用 Konva 合成方法');
      
      const konvaContainer = document.querySelector('.konvajs-content');
      if (!konvaContainer) {
        console.warn('❌ 找不到 Konva.js 容器');
        showErrorScreen('無法找到 Konva.js 容器', region);
        return;
      }
      
      const canvasLayers = Array.from(konvaContainer.querySelectorAll('canvas'));
      if (canvasLayers.length === 0) {
        console.warn('❌ Konva 容器中沒有 canvas 元素');
        showErrorScreen('未找到 canvas 元素', region);
        return;
      }
      
      console.log(`✅ 找到 ${canvasLayers.length} 個 Konva canvas 層`);
      
      const firstCanvas = canvasLayers[0];
      const canvasWidth = firstCanvas.width;
      const canvasHeight = firstCanvas.height;
      
      console.log('📏 Canvas 尺寸:', canvasWidth, 'x', canvasHeight);
      
      // 將百分比坐標轉換為像素坐標
      const sx = canvasWidth * (region.x / 100);
      const sy = canvasHeight * (region.y / 100);
      const sw = canvasWidth * (region.width / 100);
      const sh = canvasHeight * (region.height / 100);
      
      console.log('📸 擷取區域 (像素):', { sx, sy, sw, sh });
      
      // 創建合成 canvas
      const compositeCanvas = document.createElement('canvas');
      compositeCanvas.width = canvasWidth;
      compositeCanvas.height = canvasHeight;
      const compositeCtx = compositeCanvas.getContext('2d');
      
      // 按順序繪製每個 canvas 層
      canvasLayers.forEach((canvas, index) => {
        try {
          compositeCtx.drawImage(canvas, 0, 0);
          console.log(`🔄 已合併第 ${index + 1}/${canvasLayers.length} 層 canvas`);
        } catch (layerError) {
          console.warn(`⚠️ 合併第 ${index + 1} 層時出錯:`, layerError.message);
        }
      });
      
      // 從合成 canvas 中裁剪區域
      const konvaCropCanvas = document.createElement('canvas');
      konvaCropCanvas.width = sw;
      konvaCropCanvas.height = sh;
      const konvaCropCtx = konvaCropCanvas.getContext('2d');
      
      konvaCropCtx.drawImage(
        compositeCanvas, 
        sx, sy, sw, sh,  // 源區域
        0, 0, sw, sh     // 目標區域
      );
      
      // 顯示截圖結果
      showScreenshot(konvaCropCanvas.toDataURL('image/png'), region, {
        method: 'Konva 合成',
        width: sw,
        height: sh
      });
    }
  };
  
  // 從 store 中獲取原始圖像 URL 的函數
  const getOriginalImageUrl = (store) => {
    try {
      // 方法 1: 嘗試從 task 中獲取
      if (store.task && store.task.data) {
        console.log('👁️ 檢查 task.data:', store.task.data);
        
        // 遍歷 task.data 中的所有字段，尋找圖像 URL
        for (const key in store.task.data) {
          const value = store.task.data[key];
          if (typeof value === 'string' && isLikelyImageUrl(value)) {
            console.log(`✅ 在 task.data.${key} 中找到可能的圖像 URL:`, value);
            return value;
          }
        }
      }
      
      // 方法 2: 嘗試從 store.annotationStore 中獲取
      if (store.annotationStore && store.annotationStore.selected) {
        const annotation = store.annotationStore.selected;
        console.log('👁️ 檢查當前選擇的 annotation:', annotation);
        
        // 嘗試從 annotation 中找到圖像URL
        if (annotation.task && annotation.task.data) {
          for (const key in annotation.task.data) {
            const value = annotation.task.data[key];
            if (typeof value === 'string' && isLikelyImageUrl(value)) {
              console.log(`✅ 在 annotation.task.data.${key} 中找到可能的圖像 URL:`, value);
              return value;
            }
          }
        }
      }
      
      // 方法 3: 查找頁面上的圖像元素
      const imageElements = document.querySelectorAll('img');
      console.log(`👁️ 頁面上找到 ${imageElements.length} 個 img 元素`);
      
      for (const img of imageElements) {
        // 排除小圖標，只考慮可能是主圖像的元素
        if (img.width > 100 && img.height > 100 && img.src) {
          console.log('✅ 在頁面上找到可能的主圖像:', img.src);
          return img.src;
        }
      }
      
      // 方法 4: 嘗試從 store.objects 中獲取
      if (store.objects && store.objects.length > 0) {
        console.log('👁️ 檢查 store.objects:', store.objects);
        
        for (const obj of store.objects) {
          if (obj.value && typeof obj.value === 'string' && isLikelyImageUrl(obj.value)) {
            console.log('✅ 在 store.objects 中找到可能的圖像 URL:', obj.value);
            return obj.value;
          }
        }
      }
      
      // 輸出完整的 store 對象幫助調試
      console.log('📊 完整的 store 對象:', store);
      
      return null;
    } catch (error) {
      console.error('❌ 獲取圖像 URL 時出錯:', error);
      return null;
    }
  };
  
  // 判斷一個字符串是否可能是圖像 URL
  const isLikelyImageUrl = (str) => {
    if (!str || typeof str !== 'string') return false;
    
    // 檢查是否是絕對 URL 並且是常見的圖像格式
    if (str.match(/^(http|https|data):/) && 
        str.match(/\.(jpg|jpeg|png|gif|bmp|webp|svg)($|\?)|^data:image\//i)) {
      return true;
    }
    
    // 檢查是否是相對 URL 並且是常見的圖像格式
    if (str.match(/\.(jpg|jpeg|png|gif|bmp|webp|svg)($|\?)/i)) {
      return true;
    }
    
    return false;
  };
  
  // 顯示截圖結果
  const showScreenshot = (imageUrl, region, info) => {
    const newWindow = window.open('', '_blank');
    if (!newWindow) {
      console.warn('❌ 無法開啟新視窗顯示截圖');
      downloadImage(imageUrl, `region_${region.id}_screenshot.png`);
      return;
    }
    
    newWindow.document.write(`
      <html>
        <head>
          <title>Region Screenshot</title>
          <style>
            body { margin: 0; padding: 20px; text-align: center; background: #f5f5f5; font-family: Arial, sans-serif; }
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            img { max-width: 100%; border: 1px solid #ddd; display: block; margin: 0 auto 20px; }
            .info { margin: 20px 0; text-align: left; background: #f9f9f9; padding: 15px; border-radius: 4px; }
            .warning { color: #e91e63; margin-top: 10px; display: ${info.error ? 'block' : 'none'}; }
            .controls { margin-top: 20px; }
            button { padding: 8px 16px; margin: 0 5px; cursor: pointer; background: #4285f4; color: white; border: none; border-radius: 4px; }
            button:hover { background: #3367d6; }
            .method { display: inline-block; padding: 3px 8px; background: #2196f3; color: white; border-radius: 3px; font-size: 12px; margin-left: 8px; }
            .image-url { word-break: break-all; font-size: 12px; color: #666; margin-top: 8px; }
          </style>
        </head>
        <body>
          <div class="container">
            <h2>Region Screenshot <span class="method">${info.method}</span></h2>
            <img src="${imageUrl}" alt="Region Screenshot" id="screenshot">
            
            <div class="info">
              <p><strong>Region ID:</strong> ${region.id}</p>
              <p><strong>Coordinates:</strong> x=${region.x.toFixed(2)}%, y=${region.y.toFixed(2)}%, 
                 width=${region.width.toFixed(2)}%, height=${region.height.toFixed(2)}%</p>
              <p><strong>Pixel dimensions:</strong> ${info.width.toFixed(0)} × ${info.height.toFixed(0)}</p>
              <p><strong>Screenshot method:</strong> ${info.method}</p>
              ${info.imageUrl ? `<p class="image-url"><strong>Source image:</strong> ${info.imageUrl}</p>` : ''}
            </div>
            
            ${info.error ? '<p class="warning">注意: 無法獲取實際內容，僅顯示區域位置。</p>' : ''}
            
            <div class="controls">
              <button onclick="downloadImage()">下載截圖</button>
              <button onclick="window.close()">關閉</button>
            </div>
          </div>
          
          <script>
            function downloadImage() {
              const link = document.createElement('a');
              link.download = 'region_${region.id}_screenshot.png';
              link.href = document.getElementById('screenshot').src;
              link.click();
            }
          </script>
        </body>
      </html>
    `);
    
    newWindow.document.close();
  };
  
  // 顯示錯誤畫面
  const showErrorScreen = (errorMessage, region) => {
    alert(`截圖失敗: ${errorMessage}`);
  };
  
  // 下載圖像
  const downloadImage = (dataUrl, filename) => {
    const link = document.createElement('a');
    link.href = dataUrl;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <Block name="info">
      <Elem name="section-tab">
        <Elem name="section-head">
          選擇詳情
          <button
            onClick={handleScreenshot} 
            style={{ 
              marginLeft: '10px',
              padding: '2px 8px',
              background: '#f0f0f0',
              border: '1px solid #ccc',
              borderRadius: '3px',
              cursor: 'pointer'
            }}
            title="擷取選中區域的截圖"
          >
            📸 擷圖
          </button>
        </Elem>
        <RegionsPanel regions={selection} />
      </Elem>
    </Block>
  );
}));


const GeneralPanel: FC<any> = inject('store')(observer(({ store, currentEntity }) => {
  const { relationStore } = currentEntity;
  const showAnnotationHistory = store.hasInterface('annotations:history');
  const showDraftInHistory = isFF(FF_DEV_2290);

  return (
    <>
      {!showDraftInHistory ? (
        <DraftPanel item={currentEntity} />
      ) : (
        <Elem name="section">
          <Elem name="section-head">
              Annotation History
            <span>#{currentEntity.pk ?? currentEntity.id}</span>
          </Elem>
          <Elem name="section-content">
            <AnnotationHistory
              inline
              showDraft={showDraftInHistory}
              enabled={showAnnotationHistory}
            />
          </Elem>
        </Elem>
      )}
      <Elem name="section">
        <Elem name="section-head">
          Relations ({relationStore.size})
        </Elem>
        <Elem name="section-content">
          <RelationsComponent
            relationStore={relationStore}
          />
        </Elem>
      </Elem>
      {store.hasInterface('annotations:comments') && store.commentStore.isCommentable && (
        <Elem name="section">
          <Elem name="section-head">
            Comments
          </Elem>
          <Elem name="section-content">
            <CommentsComponent
              annotationStore={store.annotationStore} 
              commentStore={store.commentStore}
              cacheKey={`task.${store.task.id}`}
            />
          </Elem>
        </Elem>
      )}
    </>
  );
}));

GeneralPanel.displayName = 'GeneralPanel';

const RegionsPanel: FC<{regions: any}> = observer(({
  regions,
}) => {
  return (
    <div>
      {regions.list.map((reg: any) => {
        return (
          <SelectedRegion key={reg.id} region={reg}/>
        );
      })}
    </div>
  );
});

const SelectedRegion: FC<{region: any}> = observer(({
  region,
}) => {
  return (
    <RegionItem
      region={region}
      mainDetails={RegionDetailsMain}
      metaDetails={RegionDetailsMeta}
    />
  );
});

export const Comments = observer(CommentsTab);
export const History = observer(HistoryTab);
export const Relations = observer(RelationsTab);
export const Info = observer(InfoTab);
export const Details = observer(DetailsComponent);
export const DetailsPanel = observer(DetailsPanelComponent);