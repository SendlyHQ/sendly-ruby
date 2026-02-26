# frozen_string_literal: true

module Sendly
  class Media
    attr_reader :client

    def initialize(client)
      @client = client
    end

    def upload(file, content_type: "image/jpeg", filename: "upload.jpg")
      response = client.post_multipart("/media", file, content_type: content_type, filename: filename)
      MediaFile.new(response)
    end
  end
end
