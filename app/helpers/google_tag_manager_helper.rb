# AVR: renders the Google Tag Manager container snippet, in place of upstream's
# GA4 gtag loader. Rendered from app/views/modules/_google_analytics.html.erb,
# which both layouts already include in <head>.
module GoogleTagManagerHelper
  def render_google_tag_manager
    container_id = Settings.analytics_container_id
    return '' if container_id.blank?

    <<~HTML.html_safe
      <!-- Google Tag Manager -->
      <script>
        (function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
          new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
          j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
          'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
        })(window,document,'script','dataLayer',#{container_id.to_json});
      </script>
      <!-- End Google Tag Manager -->
    HTML
  end
end
