module PeopleHelper
  def identity_provider_icon(identity)
    case identity.provider
    when 'google_oauth2'
      'bi-google'
    when 'email'
      'bi-envelope'
    else
      'bi-person'
    end
  end

  def identity_provider_name(identity)
    case identity.provider
    when 'google_oauth2'
      'Google'
    when 'email'
      'Email'
    else
      identity.provider.titleize
    end
  end

  def identity_status_badge(identity)
    if identity.google?
      content_tag :span, 'Connected', class: 'badge bg-success'
    else
      content_tag :span, 'Email', class: 'badge bg-secondary'
    end
  end

  def can_disconnect_identity?(identity)
    current_person.can_disconnect_identity?(identity)
  end

  def connect_google_button
    button_to connect_google_identity_path, 
              method: :post, 
              class: "btn btn-outline-primary btn-sm", 
              data: { turbo: false } do
      content_tag(:i, '', class: 'bi bi-google me-2') + 'Connect Google Account'
    end
  end

  def disconnect_identity_button(identity)
    return unless can_disconnect_identity?(identity)
    
    button_to disconnect_identity_path(identity), 
              method: :delete, 
              class: "btn btn-outline-danger btn-sm",
              data: { 
                turbo: false,
                confirm: "Are you sure you want to disconnect this account? You won't be able to sign in with it anymore."
              } do
      content_tag(:i, '', class: 'bi bi-x-circle me-1') + 'Disconnect'
    end
  end

  def identity_profile_image(identity, size: 32)
    if identity.has_profile_image?
      image_tag identity.profile_image_url, 
                class: "rounded-circle", 
                style: "width: #{size}px; height: #{size}px; object-fit: cover;",
                alt: identity.name || identity.email
    else
      content_tag :div, 
                  class: "rounded-circle bg-secondary d-flex align-items-center justify-content-center text-white",
                  style: "width: #{size}px; height: #{size}px; font-size: #{size * 0.4}px;" do
        content_tag(:i, '', class: "bi #{identity_provider_icon(identity)}")
      end
    end
  end

  def identity_raw_data_display(identity)
    return unless identity.raw_data.present?
    
    content_tag :details, class: "mt-2" do
      content_tag(:summary, "View Raw Data", class: "btn btn-sm btn-outline-info") +
      content_tag(:pre, JSON.pretty_generate(identity.raw_data), class: "mt-2 p-2 bg-light rounded small")
    end
  end
end
