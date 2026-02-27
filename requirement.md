# 專案需求：dbt + OpenLineage 學習專案

## 1. 目標

透過建立一個實際可運行的專案，學習：
- dbt 基礎 CLI 操作與專案結構（快速掌握，補充已有的工作經驗）
- **OpenLineage 規範與事件模型（主要學習重點）**
- **dbt 與 OpenLineage 的整合方式與協作流程**

最終輸出：
- 可在本地完整跑通的 dbt + OpenLineage 專案（放上 GitHub）
- 每個 Milestone 對應一篇 dev.to 學習文章

## 2. 使用者背景

**工作經驗：**
- 銀行 Senior Data Engineer
- 團隊在 MWAA 上跑 10,000+ dbt processes
- 使用外部顧問設計的架構（refresh / append / upsert 三種更新策略）
- 從程式碼自學 dbt，沒有系統性教學
- 曾以 SQLLineage 自建 data lineage 解析系統

**已知的 dbt 概念：**
- ✅ macro 的用途與 config block 寫法
- ✅ Jinja templating
- ✅ 兩階段執行：Parse & Compile（產生 manifest.json）→ Execute
- ✅ manifest.json 記錄 models、dependencies、depends_on（從 ref() 自動分析）
- ✅ manifest.json 是 OpenLineage 的資料來源
- ✅ dbt 是 CLI 工具，不是常駐服務
- ❌ 實際 CLI 指令的使用方式

**學習需求：** 補充 CLI 操作，深入理解 OpenLineage 整合機制

## 3. 學習原則

- **不一步到位**：每完成一個 Milestone 再進行下一步
- 先理解概念，再動手實作，最後寫成文章輸出
- 以「能寫出清楚的學習文章」為每步完成的標準

## 4. 技術選型

### 輕量化本地開發環境

| 元件 | 選擇 | 理由 |
|------|------|------|
| dbt adapter | `dbt-duckdb` | 零安裝、embedded、file-based |
| 資料庫 | DuckDB | 無需 server，`.duckdb` 單一檔案 |
| OpenLineage 整合 | `openlineage-dbt` | 官方套件，提供 `dbt-ol` wrapper |
| 學習資料集 | jaffle_shop_duckdb seeds + 自訂 models | jaffle_shop seeds 提供現成資料，自訂 models 控制 SQL 複雜度 |
| OL 後端（初期） | File transport | 無需任何基礎設施，直接看 JSON events |
| OL 後端（進階） | Marquez | Docker Compose，提供 lineage 視覺化 UI |

### 套件管理

使用 `uv`（pyproject.toml）

### 整合架構圖

```
                    ┌─────────────────────────────┐
                    │        dbt Project           │
                    │   (jaffle_shop + DuckDB)     │
                    └─────────────┬───────────────┘
                                  │ artifacts
                                  │ (manifest.json, run_results.json, catalog.json)
                                  ▼
                    ┌─────────────────────────────┐
                    │       dbt-ol wrapper         │
                    │  (openlineage-dbt package)   │
                    └─────────────┬───────────────┘
                                  │ OpenLineage Events (JSON)
                    ┌─────────────┴───────────────┐
                    ▼                             ▼
            ┌──────────────┐            ┌──────────────────┐
            │ File Transport│            │  Marquez Backend  │
            │ (.ndjson file)│            │  (Docker Compose) │
            └──────────────┘            └──────────────────┘
             Milestone 1-2               Milestone 3-4
```

## 5. dbt Models 設計方向

### 資料來源

使用 jaffle_shop_duckdb 的三張 seed CSV（raw_customers、raw_orders、raw_payments），不使用其原有 models，改為自行設計。

### 分層設計：以 SQL 複雜度為梯度

目的不只是展示 lineage，也要測試 OpenLineage 的 column-level lineage 解析在不同複雜度下的準確度與限制。

| Layer | Model | SQL 複雜度 | 測試重點 |
|-------|-------|-----------|---------|
| Staging | `stg_orders`, `stg_customers`, `stg_payments` | 簡單 SELECT + rename/cast | 基礎 CLL，欄位直接對應 |
| Intermediate | `int_order_payments` | CTE + JOIN（多來源） | 跨 table 的欄位追蹤 |
| Marts | `mart_customer_summary` | 多層 CTE + window function + aggregation | CLL 的邊界與降級行為 |

### 預期的 CLL 行為（待實作後驗證）

```
簡單 SELECT  →  ✅ 完整追蹤（IDENTITY transform）
基本 JOIN    →  ✅ 可追蹤來源 table
單層 CTE     →  ✅ 大多正確
多層 CTE     →  ⚠️ 越深越不準
Window Func  →  ⚠️ 欄位可識別，語意丟失（標記 INDIRECT）
Aggregation  →  ⚠️ 同上
```

> **實作時機**：Milestone 1-2 先用 staging 簡單 model 跑通基礎流程，複雜 model（intermediate / marts）在 Milestone 2 的 Column-Level Lineage 階段加入，實際驗證上述預期。

---

## 6. 學習里程碑

### Milestone 1：dbt CLI 基礎 + OpenLineage 事件初探

**目標**：跑通 dbt pipeline，用肉眼讀懂第一個 OpenLineage 事件

**實作內容：**
- 建立 dbt + DuckDB 專案（基於 jaffle_shop_duckdb）
- 安裝 `openlineage-dbt`，設定 File transport
- 執行 `dbt-ol run`，解讀產生的 `.ndjson` 事件檔
- 理解 OpenLineage 三大核心實體：**Job / Run / Dataset**
- 理解事件生命週期：**START → COMPLETE / FAIL**

**完成標準**：能手動解釋一個完整 OpenLineage JSON 事件的每個欄位

**對應文章**：*dbt + OpenLineage 學習筆記 #1：從 manifest.json 到第一個 Lineage 事件*

---

### Milestone 2：Facets 機制 + Column-Level Lineage

**目標**：理解 facets 作為可擴充 metadata 的機制，掌握欄位級別 lineage

**實作內容：**
- 執行 `dbt docs generate`（產生 `catalog.json`）
- 再次 `dbt-ol run`，比較前後事件的差異
- 解讀 `SchemaDatasetFacet`（欄位名稱與型別）
- 解讀 `ColumnLineageDatasetFacet`（欄位對欄位的對應關係）
- 了解 `SqlJobFacet`（dbt model 的 compiled SQL）

**完成標準**：能說明 column-level lineage 如何從 SQL 解析出來，以及準確度的限制

**對應文章**：*dbt + OpenLineage 學習筆記 #2：Facets 是什麼？Column-Level Lineage 的原理*

---

### Milestone 3：Marquez UI 視覺化

**目標**：用圖形介面觀察 lineage graph，理解 Marquez 資料模型

**實作內容：**
- 以 Docker Compose 啟動 Marquez（API + UI + PostgreSQL）
- 切換 OpenLineage transport 為 HTTP → Marquez
- 在 Marquez UI 觀察：lineage DAG、dataset 連結、facets 詳細資訊
- 理解 Marquez 資料模型：**namespace / job / dataset / run**

**完成標準**：能在 Marquez UI 中找到 dbt 每個 model 的 lineage 關係和 run history

**對應文章**：*dbt + OpenLineage 學習筆記 #3：用 Marquez 視覺化 Data Lineage*

---

### Milestone 4：進階 Facets 與自建系統比較

**目標**：掌握 metadata 豐富化，並與過去自建系統做技術比較

**實作內容：**
- 在 dbt model YAML 加入 `meta.owner` 和 `tags`，觀察對應 facets
- 故意製造 SQL 錯誤，觀察 `FAIL` 事件與 `ErrorMessageRunFacet`
- 用 `openlineage.yml` 自訂 transport 與 facet 設定
- 對比分析：`openlineage-dbt` vs 自建 SQLLineage 系統

**完成標準**：能評估兩種方案的優缺點，並說明在工作場景下各自的適用性

**對應文章**：*dbt + OpenLineage 學習筆記 #4：進階 Facets 與自建 Lineage 系統的比較*

---

## 7. GitHub 專案結構

```
openlineage_dbt/
├── README.md                    # 專案說明、架構圖、Quick Start
├── pyproject.toml               # uv 管理的依賴
├── openlineage.yml              # OpenLineage 設定（transport、namespace 等）
├── jaffle_shop/                 # dbt 專案
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/         # stg_orders, stg_customers, stg_payments
│   │   ├── intermediate/    # int_order_payments
│   │   └── marts/           # mart_customer_summary
│   └── target/                  # dbt artifacts（.gitignore）
├── ol_events/                   # File transport 存放的事件（.gitignore）
├── docker/                      # Milestone 3 的 Marquez Docker Compose
│   └── docker-compose.yml
└── docs/                        # 各 Milestone 的學習筆記（dev.to 草稿）
    ├── milestone1.md
    ├── milestone2.md
    ├── milestone3.md
    └── milestone4.md
```

## 8. 文件規格

參考 Kafka 學習系列的寫作風格：

- **格式**：dev.to YAML front matter + Markdown
- **風格**：Learning Journey 第一人稱敘述，說明「為什麼」而非只說「怎麼做」
- **結構**：Introduction → Key Learnings → 實作細節 → Takeaways → Resources
- **元素**：表格比較、ASCII diagram、代碼塊（附上說明）
- **系列標籤**：`series: "dbt + OpenLineage Learning Series"`

## 9. 範圍限制（Out of Scope）

- Airflow / MWAA 整合（本專案不涉及 orchestration）
- 自訂 OpenLineage transport 實作（使用官方套件）
- Cloud 環境部署（純本地學習）
- dbt 進階功能（macros 深度、packages、snapshots）

## 10. 關鍵資源

- [OpenLineage dbt Integration 官方文件](https://openlineage.io/docs/integrations/dbt/)
- [OpenLineage Python Client 設定](https://openlineage.io/docs/client/python/)
- [jaffle_shop_duckdb repo](https://github.com/dbt-labs/jaffle_shop_duckdb)
- [Marquez Docker 快速啟動](https://github.com/MarquezProject/marquez)
- [OpenLineage 事件規範與範例](https://openlineage.io/docs/spec/examples/)
