# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::TemplatesResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:templates) { client.templates }

  def template_response(overrides = {})
    {
      'id' => 'tpl_abc123',
      'name' => 'Order shipped',
      'text' => 'Hi {{name}}, order {{order_id}} has shipped!',
      'variables' => [{ 'key' => 'name', 'type' => 'string' }],
      'is_preset' => false,
      'status' => 'draft',
      'version' => 1,
      'created_at' => '2026-01-15T10:00:00Z',
      'updated_at' => '2026-01-15T10:00:00Z'
    }.merge(overrides)
  end

  describe '#list' do
    it 'lists templates from /templates' do
      stub_request_with_auth(:get, '/templates',
                             response_body: { 'templates' => [template_response] })

      result = templates.list[:templates]

      expect(result.length).to eq(1)
      expect(result.first).to be_a(Sendly::Template)
      expect(result.first.name).to eq('Order shipped')
      expect(result.first.text).to eq('Hi {{name}}, order {{order_id}} has shipped!')
      expect(result.first.custom?).to be true
    end

    it 'handles an empty collection' do
      stub_request_with_auth(:get, '/templates', response_body: { 'templates' => [] })

      expect(templates.list[:templates]).to eq([])
    end
  end

  describe '#get' do
    it 'fetches a single template from /templates/:id' do
      stub_request_with_auth(:get, '/templates/tpl_abc123', response_body: template_response)

      template = templates.get('tpl_abc123')

      expect(template).to be_a(Sendly::Template)
      expect(template.id).to eq('tpl_abc123')
      expect(template.body).to eq(template.text)
      expect(template.published?).to be false
    end
  end

  describe '#create' do
    it 'posts name and text to /templates' do
      stub = stub_request(:post, "#{base_url}/templates")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: { name: 'Order shipped', text: 'Hi {{name}}!' }.to_json
        )
        .to_return(status: 201, body: template_response.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      template = templates.create(name: 'Order shipped', text: 'Hi {{name}}!')

      expect(stub).to have_been_requested
      expect(template).to be_a(Sendly::Template)
      expect(template.status).to eq('draft')
    end
  end

  describe '#update' do
    it 'patches /templates/:id with only the supplied fields' do
      stub = stub_request(:patch, "#{base_url}/templates/tpl_abc123")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: { text: 'New text {{code}}' }.to_json
        )
        .to_return(status: 200, body: template_response('text' => 'New text {{code}}').to_json,
                   headers: { 'Content-Type' => 'application/json' })

      template = templates.update('tpl_abc123', text: 'New text {{code}}')

      expect(stub).to have_been_requested
      expect(template.text).to eq('New text {{code}}')
    end
  end

  describe '#publish' do
    it 'posts to /templates/:id/publish' do
      stub_request_with_auth(:post, '/templates/tpl_abc123/publish',
                             response_body: template_response(
                               'status' => 'published',
                               'published_at' => '2026-01-15T11:00:00Z'
                             ))

      template = templates.publish('tpl_abc123')

      expect(template.published?).to be true
      expect(template.published_at).not_to be_nil
    end
  end

  describe '#delete' do
    it 'deletes /templates/:id' do
      stub = stub_request(:delete, "#{base_url}/templates/tpl_abc123")
        .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
        .to_return(status: 204, body: '')

      templates.delete('tpl_abc123')

      expect(stub).to have_been_requested
    end
  end

  describe '#unpublish' do
    it 'posts to /templates/:id/unpublish' do
      stub_request_with_auth(:post, '/templates/tpl_abc123/unpublish',
                             response_body: template_response('status' => 'draft'))

      template = templates.unpublish('tpl_abc123')

      expect(template).to be_a(Sendly::Template)
      expect(template.published?).to be false
    end

    it 'no longer posts to the /verify/templates prefix' do
      stub_request_with_auth(:post, '/templates/tpl_abc123/unpublish',
                             response_body: template_response('status' => 'draft'))

      templates.unpublish('tpl_abc123')

      expect(a_request(:post, "#{base_url}/verify/templates/tpl_abc123/unpublish"))
        .not_to have_been_made
    end
  end

  describe 'deprecated keyword arguments' do
    describe '#list' do
      it 'returns a :pagination key so old callers do not KeyError' do
        stub_request_with_auth(:get, '/templates',
                               response_body: { 'templates' => [template_response] })

        expect(templates.list).to have_key(:pagination)
        expect(templates.list[:pagination]).to be_nil
      end

      it 'raises rather than silently ignoring limit' do
        expect { templates.list(limit: 10) }
          .to raise_error(ArgumentError, /limit is not supported.*does not paginate/m)
      end

      it 'raises rather than silently ignoring type' do
        expect { templates.list(type: 'preset') }
          .to raise_error(ArgumentError, /type is not supported.*preset\?/m)
      end

      it 'raises rather than silently ignoring locale' do
        expect { templates.list(locale: 'en-GB') }
          .to raise_error(ArgumentError, /locale is not supported/)
      end

      it 'raises before issuing the request' do
        expect { templates.list(limit: 10) }.to raise_error(ArgumentError)

        expect(a_request(:get, "#{base_url}/templates")).not_to have_been_made
      end
    end

    describe '#create' do
      it 'sends the deprecated body alias as text' do
        stub = stub_request(:post, "#{base_url}/templates")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: { name: 'Order shipped', text: 'Hi {{name}}!' }.to_json
          )
          .to_return(status: 201, body: template_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })

        template = templates.create(name: 'Order shipped', body: 'Hi {{name}}!')

        expect(stub).to have_been_requested
        expect(template.text).to eq('Hi {{name}}, order {{order_id}} has shipped!')
      end

      it 'raises rather than silently ignoring locale' do
        expect { templates.create(name: 'Order shipped', text: 'Hi!', locale: 'en-GB') }
          .to raise_error(ArgumentError, /locale is not supported/)

        expect(a_request(:post, "#{base_url}/templates")).not_to have_been_made
      end

      it 'raises rather than silently ignoring is_published: true' do
        expect { templates.create(name: 'Order shipped', text: 'Hi!', is_published: true) }
          .to raise_error(ArgumentError, /is_published: true is not supported.*publish\(id\)/m)

        expect(a_request(:post, "#{base_url}/templates")).not_to have_been_made
      end

      it 'accepts is_published: false because templates are created as drafts' do
        stub = stub_request(:post, "#{base_url}/templates")
          .with(body: { name: 'Order shipped', text: 'Hi!' }.to_json)
          .to_return(status: 201, body: template_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })

        template = templates.create(name: 'Order shipped', text: 'Hi!', is_published: false)

        expect(stub).to have_been_requested
        expect(template.status).to eq('draft')
      end

      it 'still requires text or body' do
        expect { templates.create(name: 'Order shipped') }
          .to raise_error(ArgumentError, /text is required/)
      end
    end

    describe '#update' do
      it 'sends the deprecated body alias as text' do
        stub = stub_request(:patch, "#{base_url}/templates/tpl_abc123")
          .with(body: { text: 'New text {{code}}' }.to_json)
          .to_return(status: 200, body: template_response('text' => 'New text {{code}}').to_json,
                     headers: { 'Content-Type' => 'application/json' })

        template = templates.update('tpl_abc123', body: 'New text {{code}}')

        expect(stub).to have_been_requested
        expect(template.text).to eq('New text {{code}}')
      end

      it 'raises rather than silently ignoring locale' do
        expect { templates.update('tpl_abc123', name: 'Renamed', locale: 'en-GB') }
          .to raise_error(ArgumentError, /locale is not supported/)

        expect(a_request(:patch, "#{base_url}/templates/tpl_abc123")).not_to have_been_made
      end

      it 'raises rather than silently ignoring is_published: true' do
        expect { templates.update('tpl_abc123', name: 'Renamed', is_published: true) }
          .to raise_error(ArgumentError, /is_published: true is not supported.*publish\(id\)/m)

        expect(a_request(:patch, "#{base_url}/templates/tpl_abc123")).not_to have_been_made
      end

      it 'accepts is_published: false because an update never changes status' do
        stub = stub_request(:patch, "#{base_url}/templates/tpl_abc123")
          .with(body: { name: 'Renamed' }.to_json)
          .to_return(status: 200, body: template_response('name' => 'Renamed').to_json,
                     headers: { 'Content-Type' => 'application/json' })

        template = templates.update('tpl_abc123', name: 'Renamed', is_published: false)

        expect(stub).to have_been_requested
        expect(template.name).to eq('Renamed')
      end
    end
  end

  describe 'restored Template members' do
    it 'derives type from is_preset' do
      expect(Sendly::Template.new(template_response('is_preset' => true)).type).to eq('preset')
      expect(Sendly::Template.new(template_response).type).to eq('custom')
      expect(Sendly::Template::TYPES).to eq(%w[preset custom])
    end

    it 'derives is_published from status' do
      expect(Sendly::Template.new(template_response('status' => 'published')).is_published).to be true
      expect(Sendly::Template.new(template_response).is_published).to be false
    end

    it 'exposes locale and is_default with their documented empty values' do
      template = Sendly::Template.new(template_response)

      expect(template.locale).to be_nil
      expect(template.is_default).to be false
    end

    it 'includes the restored members in to_h' do
      hash = Sendly::Template.new(template_response).to_h

      expect(hash[:body]).to eq(hash[:text])
      expect(hash[:type]).to eq('custom')
      expect(hash[:is_published]).to be false
    end
  end
end
