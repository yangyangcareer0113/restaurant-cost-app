// Supabase Edge Function: inline-proxy
// 伺服器端取得 inline.com 新舊客資料，繞過前端 CORS 限制

const FB_KEY = 'AIzaSyAfHlsBd2WjrijkX4G26oHo0Tci-TZ5E-g';
const FB_REFRESH = 'AMf-vBx4QKdhUNl3N--cjL6ha3TCKi871iKc8Wt4tr6T_qze2lU9wIYwyx1uANM2-8HUsQA4KpPWXefEA0WsjFVKoj6EhDdfohEF99i-H05YayRVt-YhbcrWx79u_GEX7YAD4ieD8XxzctSYoEBTrWrihts4GnlzxIJCcHRojPfqxGR-gG4ZfnZLbjkIopmuR5kee_mNmD0s7PL2ocjdxHjWscfSqHpcDw';
const COMPANY_ID = '-OXcFVY2N8uB3Js-Sqv5:inline-live-3';
const BRANCH_ID = '-ObBPoad2sWT28Uj274H';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const year  = url.searchParams.get('year');
    const month = url.searchParams.get('month');

    if (!year || !month) {
      return new Response(JSON.stringify({ error: 'Missing year or month' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const y  = parseInt(year);
    const m  = parseInt(month);
    const mm = String(m).padStart(2, '0');
    const lastDay = new Date(y, m, 0).getDate();

    // 結束：請求月份的最後一毫秒（台灣時間）
    const to = new Date(`${y}-${mm}-${String(lastDay).padStart(2, '0')}T23:59:59+08:00`).getTime();

    // 開始：往前推 14 個月（涵蓋上月 + 當月 + 歷史趨勢）
    let startY = y;
    let startM = m - 14;
    while (startM <= 0) { startM += 12; startY -= 1; }
    const smm = String(startM).padStart(2, '0');
    const from = new Date(`${startY}-${smm}-01T00:00:00+08:00`).getTime();

    // Firebase token refresh
    const tokenRes = await fetch(
      `https://securetoken.googleapis.com/v1/token?key=${FB_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(FB_REFRESH)}`,
      }
    );
    const tokenData = await tokenRes.json();
    if (!tokenData.id_token) {
      return new Response(
        JSON.stringify({ error: 'Firebase token refresh failed', detail: tokenData }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // inline API — authorization 直接送 JWT（不加 Bearer 前綴）
    const apiUrl = `https://myinline.com/api/v2/dashboard/monthly-regular-and-new-customer-comparison` +
      `?companyId=${encodeURIComponent(COMPANY_ID)}` +
      `&branchId=${encodeURIComponent(BRANCH_ID)}` +
      `&range%5Bto%5D=${to}` +
      `&range%5Bfrom%5D=${from}` +
      `&timeZone=Asia%2FTaipei`;

    const apiRes = await fetch(apiUrl, {
      headers: {
        'authorization': tokenData.id_token,
        'accept': 'application/json',
        'referer': 'https://myinline.com/',
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36',
        'sec-ch-ua-platform': 'macOS',
      },
    });

    if (!apiRes.ok) {
      const errText = await apiRes.text();
      return new Response(
        JSON.stringify({ error: 'inline API error', status: apiRes.status, detail: errText }),
        { status: apiRes.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const data = await apiRes.json();
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
