/**
 * Analytics Service - Amplitude Integration
 * Gère le tracking des événements et des erreurs
 */

interface AmplitudeConfig {
  apiKey: string
  userId?: string
  sessionId?: string
}

interface AmplitudeWindow extends Window {
  amplitude?: {
    getInstance: () => {
      init: (key: string, userId?: string) => void
      logEvent: (event: string, properties?: Record<string, unknown>) => void
      setUserId: (userId: string) => void
    }
  }
}

class AnalyticsService {
  private apiKey: string
  private userId: string | null = null
  private sessionId: string
  private isInitialized = false

  constructor(config: AmplitudeConfig) {
    this.apiKey = config.apiKey
    this.userId = config.userId || null
    this.sessionId = config.sessionId || this.generateSessionId()
  }

  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  public init(): void {
    if (this.isInitialized) {
      console.warn('⚠️ Analytics already initialized')
      return
    }

    try {
      // Charger Amplitude de manière sécurisée
      const script = document.createElement('script')
      script.src = 'https://cdn.amplitude.com/libs/amplitude-8.17.0-min.gz.js'
      script.async = true
      script.integrity = 'sha384-...' // À ajouter si disponible

      script.onload = () => {
        const ampWindow = window as AmplitudeWindow
        if (ampWindow.amplitude) {
          ampWindow.amplitude.getInstance().init(this.apiKey, this.userId || undefined)
          this.isInitialized = true
          console.log('✅ Amplitude initialized successfully')
          
          // Tracker le chargement de la page
          this.trackPageView('app_loaded')
        }
      }

      script.onerror = () => {
        console.error('❌ Failed to load Amplitude')
        this.isInitialized = false
      }

      document.head.appendChild(script)
    } catch (error) {
      console.error('❌ Error initializing Amplitude:', error)
      this.isInitialized = false
    }
  }

  public setUserId(userId: string): void {
    this.userId = userId
    const ampWindow = window as AmplitudeWindow
    if (ampWindow.amplitude && this.isInitialized) {
      ampWindow.amplitude.getInstance().setUserId(userId)
    }
  }

  public trackEvent(eventName: string, eventProperties?: Record<string, unknown>): void {
    const ampWindow = window as AmplitudeWindow
    if (ampWindow.amplitude && this.isInitialized) {
      ampWindow.amplitude.getInstance().logEvent(eventName, {
        ...eventProperties,
        sessionId: this.sessionId,
        timestamp: new Date().toISOString()
      })
    } else {
      console.warn(`⚠️ Amplitude not ready. Event "${eventName}" not tracked.`)
    }
  }

  public trackPageView(pageName: string): void {
    this.trackEvent('page_view', { page: pageName })
  }

  public trackUserAction(action: string, metadata?: Record<string, unknown>): void {
    this.trackEvent('user_action', { action, ...metadata })
  }

  public trackError(error: Error | { code: string; message: string }): void {
    const errorData = error instanceof Error
      ? { message: error.message, stack: error.stack }
      : { code: error.code, message: error.message }

    this.trackEvent('error', errorData)
  }

  public isReady(): boolean {
    return this.isInitialized
  }
}

// Singleton instance
let analyticsInstance: AnalyticsService | null = null

export const initAnalytics = (config: AmplitudeConfig): AnalyticsService => {
  if (!analyticsInstance) {
    analyticsInstance = new AnalyticsService(config)
    analyticsInstance.init()
  }
  return analyticsInstance
}

export const getAnalytics = (): AnalyticsService => {
  if (!analyticsInstance) {
    throw new Error('Analytics not initialized. Call initAnalytics first.')
  }
  return analyticsInstance
}

export default AnalyticsService

