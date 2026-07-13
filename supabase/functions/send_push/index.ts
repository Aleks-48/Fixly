import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Вспомогательный класс для работы с Google OAuth2 JWT
class GoogleAuth {
  private email: string
  private privateKey: string

  constructor(email: string, privateKey: string) {
    this.email = email
    // Очищаем приватный ключ от лишних экранирований, если они есть
    this.privateKey = privateKey.replace(/\\n/g, '\n')
  }

  // Импорт приватного ключа в формат Web Crypto
  private async importPrivateKey(pem: string): Promise<CryptoKey> {
    const pemHeader = "-----BEGIN PRIVATE KEY-----"
    const pemFooter = "-----END PRIVATE KEY-----"
    
    const pemContents = pem
      .replace(pemHeader, "")
      .replace(pemFooter, "")
      .replace(/\s/g, "")

    const binaryDerString = atob(pemContents)
    const binaryDer = new Uint8Array(binaryDerString.length)
    for (let i = 0; i < binaryDerString.length; i++) {
      binaryDer[i] = binaryDerString.charCodeAt(i)
    }

    return await crypto.subtle.importKey(
      "pkcs8",
      binaryDer.buffer,
      {
        name: "RSASSA-PKCS1-v1_5",
        hash: "SHA-256",
      },
      false,
      ["sign"]
    )
  }

  // Кодирование в Base64URL
  private base64url(source: ArrayBuffer | string): string {
    let encodedString = ""
    if (typeof source === "string") {
      encodedString = btoa(source)
    } else {
      const bytes = new Uint8Array(source)
      let binary = ""
      for (let i = 0; i < bytes.byteLength; i++) {
        binary += String.fromCharCode(bytes[i])
      }
      encodedString = btoa(binary)
    }
    return encodedString
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
  }

  // Создание подписанного JWT токена
  async generateJWT(): Promise<string> {
    const iat = Math.floor(Date.now() / 1000)
    const exp = iat + 3600 // Токен на 1 час

    const header = JSON.stringify({ alg: "RS256", typ: "JWT" })
    const payload = JSON.stringify({
      iss: this.email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: exp,
      iat: iat,
    })

    const encodedHeader = this.base64url(header)
    const encodedPayload = this.base64url(payload)
    const tokenInput = `${encodedHeader}.${encodedPayload}`

    const cryptoKey = await this.importPrivateKey(this.privateKey)
    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      new TextEncoder().encode(tokenInput)
    )

    const encodedSignature = this.base64url(signature)
    return `${tokenInput}.${encodedSignature}`
  }

  // Получение Access Token от Google
  async getAccessToken(): Promise<string> {
    const jwt = await this.generateJWT()
    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Failed to get OAuth token: ${errorText}`)
    }

    const data = await response.json()
    return data.access_token
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { building_id, title, body, data: extraData } = await req.json()

    // 1. Создаем клиент Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // 2. Получаем все fcm_token для жителей данного дома
    const { data: profiles, error } = await supabaseClient
      .from('profiles')
      .select('fcm_token')
      .eq('building_id', building_id)
      .not('fcm_token', 'is', null)

    if (error) {
      throw error
    }

    const tokens = profiles
      .map((p) => p.fcm_token)
      .filter((token) => token && token.trim().length > 0)

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No tokens found for this building' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // 3. Получаем переменные окружения Firebase Service Account
    const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')
    const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID') ?? 'fixly-chat'

    if (!clientEmail || !privateKey) {
      throw new Error('FIREBASE_CLIENT_EMAIL or FIREBASE_PRIVATE_KEY is not configured in Supabase secrets')
    }

    // 4. Генерируем Google OAuth2 Access Token
    const auth = new GoogleAuth(clientEmail, privateKey)
    const accessToken = await auth.getAccessToken()

    // 5. Отправляем пуши каждому устройству по отдельности через HTTP v1 API
    const results = []
    for (const token of tokens) {
      try {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: token,
              notification: {
                title: title,
                body: body,
              },
              data: extraData ? Object.keys(extraData).reduce((acc, key) => {
                // Все значения в data должны быть String в Firebase v1 API
                acc[key] = String(extraData[key])
                return acc
              }, {} as Record<string, string>) : {},
            },
          }),
        })
        const resJson = await res.json()
        results.push({ token: token.substring(0, 10) + '...', status: res.status, response: resJson })
      } catch (err) {
        results.push({ token: token.substring(0, 10) + '...', error: err.message })
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
