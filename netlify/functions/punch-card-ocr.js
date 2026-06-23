// Netlify Function: punch-card-ocr
// 接收 base64 打卡表圖片 → 呼叫 Claude API → 回傳結構化出勤資料

exports.handler = async (event) => {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers, body: JSON.stringify({ error: 'Method Not Allowed' }) };
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: 'ANTHROPIC_API_KEY 未設定' }) };
  }

  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return { statusCode: 400, headers, body: JSON.stringify({ error: '無法解析請求內容' }) };
  }

  const { images } = body; // images: [{ base64: string, mimeType: string }]
  if (!images || !images.length) {
    return { statusCode: 400, headers, body: JSON.stringify({ error: '未提供圖片' }) };
  }

  // 組成 message content：每張圖片 + 統一指令
  const content = [];
  for (const img of images) {
    content.push({
      type: 'image',
      source: { type: 'base64', media_type: img.mimeType, data: img.base64 },
    });
  }
  content.push({
    type: 'text',
    text: `這是員工傳統打卡表的照片（可能有1到2張，分別代表上半月和下半月）。
請逐日讀取所有有出勤記錄的日期，回傳以下 JSON 格式（只回傳 JSON，不要任何說明文字）：

{
  "days": [
    {
      "date": 1,
      "am_in": "09:48",
      "am_out": "14:03",
      "pm_in": "16:00",
      "pm_out": "21:20",
      "ot_in": null,
      "ot_out": null,
      "total_hours": 9.33,
      "late": false,
      "notes": ""
    }
  ]
}

規則：
- date = 日期數字（1-31）
- 時間格式：HH:MM（24小時制），無記錄填 null
- total_hours = 卡片上「小計」欄的數字（若無則自行計算）
- late = 時間有圓圈標記（遲到）填 true，否則 false
- notes = 特殊備註（如跨午夜、紅箭頭延伸加班等）
- 空班日期不要包含在陣列內`,
  });

  try {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 2048,
        messages: [{ role: 'user', content }],
      }),
    });

    const data = await res.json();
    if (!res.ok) {
      return { statusCode: 502, headers, body: JSON.stringify({ error: data.error?.message || 'Claude API 錯誤' }) };
    }

    const rawText = data.content?.[0]?.text || '';
    // 嘗試清理並解析 JSON
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return { statusCode: 200, headers, body: JSON.stringify({ raw: rawText, days: [] }) };
    }
    const parsed = JSON.parse(jsonMatch[0]);
    return { statusCode: 200, headers, body: JSON.stringify(parsed) };
  } catch (err) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: err.message }) };
  }
};
