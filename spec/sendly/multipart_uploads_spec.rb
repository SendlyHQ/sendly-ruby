# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe 'Uploads that build their own multipart body' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:pdf) { "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n".b }
  let(:json_ok) { { status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' } } }
  let(:boundary) { "SendlyRuby#{'0' * 32}" }

  def with_file(name)
    Dir.mktmpdir do |dir|
      path = File.join(dir, name)
      File.binwrite(path, pdf)
      yield path
    end
  end

  def capture_body(url)
    sent = nil
    stub_request(:post, url).with { |req| sent = req.body.b }.to_return(json_ok)
    yield
    sent
  end

  def file_disposition(body)
    body[/^Content-Disposition: form-data; name="(?:file|einDoc)"[^\r\n]*/]
  end

  def fixed_boundary
    allow(SecureRandom).to receive(:hex).and_call_original
    allow(SecureRandom).to receive(:hex).with(16).and_return('0' * 32)
  end

  describe 'enterprise.upload_verification_document' do
    let(:url) { "#{base_url}/enterprise/verification-document/upload" }

    it 'uploads a document whose filename is not ASCII' do
      sent = capture_body(url) do
        with_file('café.pdf') { |path| client.enterprise.upload_verification_document(path) }
      end

      expect(sent).to include(pdf)
      expect(file_disposition(sent)).to eq('Content-Disposition: form-data; name="file"; filename="café.pdf"'.b)
    end

    it 'writes a quote, carriage return or line feed in the filename as %22, %0D or %0A' do
      sent = capture_body(url) do
        with_file("ein \"2026\"\r\n.pdf") { |path| client.enterprise.upload_verification_document(path) }
      end

      expect(file_disposition(sent)).to eq('Content-Disposition: form-data; name="file"; filename="ein %222026%22%0D%0A.pdf"')
    end

    it 'sends an ASCII upload byte for byte as before' do
      fixed_boundary
      sent = capture_body(url) do
        with_file('ein.pdf') { |path| client.enterprise.upload_verification_document(path, workspace_id: 'ws_1') }
      end

      expected = "--#{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"ein.pdf\"\r\n" \
                 "Content-Type: application/pdf\r\n\r\n".b + pdf +
                 "\r\n--#{boundary}\r\nContent-Disposition: form-data; name=\"workspaceId\"\r\n\r\nws_1" \
                 "\r\n--#{boundary}--\r\n".b
      expect(sent).to eq(expected)
    end
  end

  describe 'business_upgrade.start' do
    let(:url) { "#{base_url}/workspaces/ws_1/upgrade" }
    let(:required) { { brn: '12-3456789', brn_type: 'EIN', brn_country: 'US', entity_type: 'PRIVATE_PROFIT' } }

    it 'sends a business name that is not ASCII next to an EIN document' do
      sent = capture_body(url) do
        client.business_upgrade.start('ws_1', business_name: 'Café Ltd', ein_doc: pdf, **required)
      end

      expect(sent).to include('Café Ltd'.b)
      expect(sent).to include(pdf)
    end

    it 'writes a quote, carriage return or line feed in the EIN document filename as %22, %0D or %0A' do
      sent = capture_body(url) do
        client.business_upgrade.start('ws_1', business_name: 'Acme Ltd', ein_doc: pdf,
                                              ein_doc_filename: "ein \"2026\"\r\n.pdf", **required)
      end

      expect(file_disposition(sent)).to eq('Content-Disposition: form-data; name="einDoc"; filename="ein %222026%22%0D%0A.pdf"')
    end

    it 'sends an ASCII upload byte for byte as before' do
      fixed_boundary
      sent = capture_body(url) do
        client.business_upgrade.start('ws_1', business_name: 'Acme Ltd', ein_doc: pdf, **required)
      end

      expect(sent).to start_with("--#{boundary}\r\nContent-Disposition: form-data; name=\"".b)
      expect(sent).to end_with("Content-Disposition: form-data; name=\"einDoc\"; filename=\"ein-doc.pdf\"\r\n" \
                               "Content-Type: application/pdf\r\n\r\n".b + pdf + "\r\n--#{boundary}--\r\n".b)
      expect(sent).to include("\r\n\r\nAcme Ltd\r\n".b)
    end
  end
end
